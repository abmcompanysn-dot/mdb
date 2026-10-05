Tu travailles seul, sans jamais poser de question. Économise le contexte : lis seulement ce qui sert à la tâche.

1. Lis CLAUDE.md. Ne relis pas OBJECTIF.md, DECISIONS.md ni SPEC_TECHNIQUE.md en entier :
   cherche-y seulement (grep) les passages liés à ta tâche.
2. Ta tâche : la première ligne « - [ ] » de TACHES.md (utilise grep -m1, ne lis pas tout le fichier).
   Lis les 10 dernières lignes de JOURNAL.md.
3. Ouvre uniquement les fichiers du module concerné. Ne lis jamais node_modules, .next, bin, le code généré par sqlc,
   ni les fichiers de logs en entier (utilise tail).
4. Écris le code et les tests qui prouvent le critère « Terminé quand ».
5. Teste d'abord seulement le module (ex. « go test ./backend/internal/catalog/... » ou « pnpm --filter dashboard test »).
   Quand c'est vert, lance « make test » une seule fois. Corrige jusqu'à ce que TOUS les tests passent,
   sans supprimer ni désactiver de test.
6. Clé externe manquante : implémentation « simulated », tâche « - [~] », une ligne dans BLOCAGES.md, et continue.
7. Décision non couverte : la plus simple, une ligne à la fin de DECISIONS.md.
8. Ajoute 3 lignes courtes à JOURNAL.md : fait, fragile, prochaine étape.
9. Coche la tâche, puis « git add -A » et « git commit -m "<numéro>: <résumé>" ».
10. Arrête-toi après UNE tâche. Réponse finale : une seule ligne.

Interdits : lire ou modifier .env, écrire une clé dans un fichier, appeler un service de paiement réel,
déployer en production, git push, supprimer l'historique.
