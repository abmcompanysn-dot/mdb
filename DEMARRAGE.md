# Démarrage de la boucle

## 1. Mettre le kit dans le dépôt

Copier tous les fichiers de ce kit à la racine du dépôt GitHub (y compris le dossier `.claude/`), puis :

```bash
chmod +x boucle.sh
printf ".env\nlogs/\nSTOP\ndata/\n" >> .gitignore
git add -A && git commit -m "Kit de la boucle autonome"
```

## 1 bis. Tout avec Claude Code

La boucle construit tout, Phase 0 comprise. Pour limiter la consommation de tokens :
modèle Sonnet par défaut, Opus seulement pour les tâches sensibles (authentification, paiements, sécurité),
pause automatique quand la limite du forfait est atteinte. Réglages en haut de `boucle.sh`.

## 2. Ce qu'il faut fournir à Claude, et comment

Règle : Claude ne voit JAMAIS les clés. Elles vont dans `.env` (sur la machine de la boucle) ou dans les secrets GitHub.
Le code les lit au moment de s'exécuter. Sans clé, le service tourne en mode simulé et la boucle continue.

| Quoi | Où le mettre | Quand | Sans ça |
| --- | --- | --- | --- |
| Rien de spécial | — | Phase 0 à Sprint 2 | Tout tourne en local avec Docker |
| `SESSION_SECRET`, `ENCRYPTION_KEY` (`openssl rand -hex 32`) | `.env` | Dès le début | Clés de développement générées |
| Clés **test** de l'agrégateur (Wave, Orange Money) | `.env` | Sprint 3 | Paiement simulé |
| Clés **test** Stripe (`sk_test_…`, `pk_test_…`) | `.env` | Sprint 3 | Carte simulée |
| Amazon SES (test) | `.env` | Sprint 5 | Emails dans Mailpit local |
| Cloudflare R2 | `.env` | Sprint 1 | Photos dans un dossier local |
| Application Meta en mode développement + code d'événement test | `.env` | Sprint 6 | Meta simulé |
| Ton serveur Kafka de test | `.env` (`KAFKA_TEST_…`) | Phase 0 | Redpanda local |
| Accès au VPS (`ssh root@…`) | Toi seulement, pour lancer `infra/preparer-vps.sh` une fois | Avant tout | — |
| Nom de domaine pointé vers le VPS + jeton DNS Cloudflare | `.env` (`CLOUDFLARE_DNS_API_TOKEN`) | Phase 0 | Serveur de test sans HTTPS public |
| Clés de **production** | Secrets Kubernetes du namespace `prod`, créés par toi | Au lancement | — |

Copier `env.example` en `.env` et remplir seulement ce que tu as déjà. Tu pourras ajouter les autres plus tard :
au passage suivant, la boucle les utilisera automatiquement.

## 3. Le VPS : une seule machine pour tout

Le VPS sert à la fois d'ordinateur de développement (la boucle y tourne), de serveur de test
(namespace `staging`) et plus tard de production (namespace `prod`), le tout sous Kubernetes (k3s).

Taille conseillée au départ : 8 vCPU, 16 à 32 Go de mémoire, 200 Go de disque NVMe, Ubuntu 24.04.

1. Connecte-toi : `ssh root@<ip-du-vps>` (avec une clé SSH, pas un mot de passe).
2. Copie et lance une seule fois : `sudo bash infra/preparer-vps.sh`.
   Il installe le pare-feu, Docker, k3s, le registre d'images, Go, Node.js, Claude Code,
   crée l'utilisateur `claude` et un accès Kubernetes limité aux namespaces `dev` et `staging`.
3. Reconnecte-toi en `claude` (`ssh claude@<ip-du-vps>`), lance `claude` une fois pour te connecter à ton compte,
   clone le dépôt, copie `env.example` en `.env` et remplis ce que tu as.

Ne donne jamais l'accès root à Claude : la boucle travaille avec l'utilisateur `claude`
et ne peut pas toucher au namespace `prod`. Quand la plateforme aura de vrais clients,
on déplacera la production sur un deuxième VPS.

## 4. Lancer

```bash
./boucle.sh
```

- Arrêter : `touch STOP` (la boucle finit le passage en cours puis s'arrête). Reprendre : `rm STOP && ./boucle.sh`.
- Changer la limite de passages : `MAX_PASSAGES=120 ./boucle.sh`.

## 5. Suivre sans rien tester

- `JOURNAL.md` : ce qui a été fait à chaque tâche.
- `BLOCAGES.md` : les clés manquantes et les tâches mises de côté.
- `TACHES.md` : `[x]` fait, `[~]` fait en simulé (ajouter la clé puis relancer), `[!]` mis de côté.
- `https://test.<ton-domaine>` : la plateforme à jour après chaque tâche réussie (namespace `staging`).

## 6. Ce que la boucle ne fait jamais

Ouvrir des comptes, signer des contrats, utiliser de l'argent réel, déployer en production.
Ces étapes restent à toi.
