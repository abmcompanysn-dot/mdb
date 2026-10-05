#!/usr/bin/env bash
# =====================================================================
# Boucle autonome : relance Claude Code tâche après tâche jusqu'à la fin
# de TACHES.md. Pour arrêter : créer un fichier vide nommé STOP.
# =====================================================================
set -uo pipefail

MAX_PASSAGES=${MAX_PASSAGES:-80}     # limite de sécurité
MAX_REPARATIONS=2                    # essais de réparation si les tests échouent
BRANCHE=${BRANCHE:-boucle}
MODELE_DEFAUT=${MODELE_DEFAUT:-sonnet}   # modèle économique pour la plupart des tâches
MODELE_FORT=${MODELE_FORT:-opus}         # modèle fort pour les tâches sensibles
TACHES_FORTES='^(P0\.4|P0\.5|P0\.6|S3\.|S6\.3|S6\.4|S7\.2|S7\.5|S8\.1)'
PAUSE_LIMITE=${PAUSE_LIMITE:-3600}   # attente (secondes) quand la limite du forfait est atteinte

mkdir -p logs
touch JOURNAL.md BLOCAGES.md
if [ -f .env ]; then set -a; . ./.env; set +a; fi
git checkout -B "$BRANCHE" >/dev/null 2>&1 || true

# Lance Claude ; si la limite d'utilisation est atteinte, attend puis réessaie.
lancer_claude() {
  local modele="$1" consigne="$2"
  while true; do
    [ -f STOP ] && return 1
    claude -p --model "$modele" "$consigne" > logs/derniere-reponse.log 2>&1
    local code=$?
    cat logs/derniere-reponse.log >> logs/claude.log
    if [ $code -ne 0 ] && grep -qiE 'usage limit|rate limit|limit reached|quota' logs/derniere-reponse.log; then
      echo "$(date '+%F %T')   limite du forfait atteinte, pause de $PAUSE_LIMITE s" | tee -a logs/boucle.log
      sleep "$PAUSE_LIMITE"
      continue
    fi
    return 0
  done
}

for i in $(seq 1 "$MAX_PASSAGES"); do
  if ! grep -q '^- \[ \]' TACHES.md; then
    echo "$(date '+%F %T') Toutes les tâches sont terminées." | tee -a logs/boucle.log; exit 0
  fi
  [ -f STOP ] && { echo "$(date '+%F %T') Arrêt demandé (fichier STOP)." | tee -a logs/boucle.log; exit 0; }

  LIGNE=$(grep -m1 '^- \[ \]' TACHES.md)
  ID=$(echo "$LIGNE" | awk '{print $4}')
  TACHE=$(echo "$LIGNE" | cut -c7-70)
  MODELE=$MODELE_DEFAUT
  echo "$ID" | grep -qE "$TACHES_FORTES" && MODELE=$MODELE_FORT
  AVANT=$(git rev-parse HEAD 2>/dev/null || echo "aucun")
  echo "$(date '+%F %T') Passage $i : $TACHE ($MODELE)" | tee -a logs/boucle.log

  lancer_claude "$MODELE" "$(cat prompts/boucle.md)" || exit 0

  ok=0
  for r in $(seq 0 "$MAX_REPARATIONS"); do
    if make test > logs/tests.log 2>&1; then ok=1; break; fi
    [ "$r" -eq "$MAX_REPARATIONS" ] && break
    # Seulement la fin du journal de tests, pour économiser les tokens
    grep -iE 'fail|error|panic|expected' logs/tests.log | tail -n 60 > logs/echecs.txt
    tail -n 20 logs/tests.log >> logs/echecs.txt
    echo "$(date '+%F %T')   tests en échec, réparation $((r+1))" | tee -a logs/boucle.log
    lancer_claude "$MODELE" "Les tests échouent. Lis seulement logs/echecs.txt. Corrige le code sans supprimer ni désactiver de test, relance d'abord les tests du module concerné puis make test, et fais un commit. Ne pose aucune question. Réponse finale : une ligne." || exit 0
  done

  if [ "$ok" -eq 1 ]; then
    if [ "$(git rev-parse HEAD)" != "$AVANT" ]; then
      git push -q origin "$BRANCHE" >> logs/boucle.log 2>&1 \
        && echo "$(date '+%F %T')   OK, poussé sur $BRANCHE" | tee -a logs/boucle.log
      if make deploy-staging >> logs/deploy.log 2>&1 && make smoke-staging >> logs/deploy.log 2>&1; then
        echo "$(date '+%F %T')   déployé sur staging" | tee -a logs/boucle.log
      elif grep -q '^deploy-staging:' Makefile 2>/dev/null; then
        echo "$(date '+%F %T')   déploiement en échec, retour à la version précédente" | tee -a logs/boucle.log
        for d in $(kubectl -n staging get deploy -o name 2>/dev/null); do
          kubectl -n staging rollout undo "$d" >> logs/deploy.log 2>&1 || true
        done
        echo "- $(date '+%F') Déploiement staging en échec après « $TACHE » (voir logs/deploy.log)." >> BLOCAGES.md
        git add BLOCAGES.md && git commit -qm "boucle: déploiement staging en échec"
      fi
    fi
  else
    echo "$(date '+%F %T')   échec après $MAX_REPARATIONS réparations, retour à l'état précédent" | tee -a logs/boucle.log
    git reset -q --hard "$AVANT"
    git clean -fdq -e .env -e logs
    sed -i '0,/^- \[ \]/s//- [!]/' TACHES.md
    echo "- $(date '+%F') Tâche « $TACHE » : tests toujours en échec (voir logs/tests.log)." >> BLOCAGES.md
    git add TACHES.md BLOCAGES.md && git commit -qm "boucle: tâche mise de côté ($ID)"
  fi
done
echo "$(date '+%F %T') Limite de $MAX_PASSAGES passages atteinte." | tee -a logs/boucle.log
