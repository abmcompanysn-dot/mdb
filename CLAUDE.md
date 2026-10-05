# Règles du projet

Tu construis la plateforme décrite dans OBJECTIF.md, tâche par tâche, en suivant TACHES.md.
La base doit suivre exactement SPEC_TECHNIQUE.md (arborescence, tables, routes, événements).
Tu travailles seul : ne pose jamais de question à l'utilisateur. Décide selon DECISIONS.md,
et pour toute nouvelle décision, choisis l'option la plus simple et note-la dans DECISIONS.md.

## Économie de tokens

- Lis le minimum : grep et tail plutôt que des fichiers entiers ; seulement le module de la tâche.
- Jamais node_modules, .next, bin, data, logs complets, code généré (sqlc, client OpenAPI).
- Tests ciblés d'abord, `make test` complet une seule fois à la fin.
- Pas de longues explications : code, tests, 3 lignes de journal, une ligne de réponse finale.

## Façon de travailler

- Une tâche à la fois. Elle n'est terminée que si son critère « Terminé quand » est prouvé par un test.
- Toujours lancer `make test` avant de cocher une tâche. Ne jamais désactiver ou supprimer un test pour le faire passer.
- Un commit par tâche, message au format `S3.2: checkout mobile en une page`.
- Ajouter 3 lignes dans JOURNAL.md à chaque tâche : fait, fragile, prochaine étape.
- Si un service externe n'a pas de clé : utiliser l'implémentation `simulated`, cocher `- [~]`, noter dans BLOCAGES.md, continuer.

## Architecture

- `backend/internal/<module>` : chaque module a ses tables, ses requêtes sqlc, ses routes et ses événements. Un module ne lit jamais directement les tables d'un autre ; il passe par son interface Go ou par un événement Kafka.
- Toute route est d'abord décrite dans `contracts/openapi.yaml`. Le tableau de bord utilise uniquement l'API publique.
- Chaque événement Kafka a un schéma dans `contracts/events/`, un `id` unique, un `vendeur_id`, une date.
- Les consommateurs Kafka sont idempotents (un événement lu deux fois ne fait qu'un effet).

## Sécurité

- Chaque table métier a `vendeur_id` et la Row Level Security de PostgreSQL. Toujours tester qu'un vendeur ne voit pas les données d'un autre.
- Argent : entiers en plus petite unité (XOF), devise enregistrée, jamais de float.
- Secrets : uniquement par variables d'environnement. Ne jamais lire `.env`, ne jamais écrire une clé dans le code, les tests, les logs ou un commit.
- Jetons d'accès externes (Meta, paiement) chiffrés en base avec `ENCRYPTION_KEY`.
- Webhooks entrants : signature vérifiée, idempotence.
- Mots de passe hachés (argon2id), cookies HttpOnly + Secure + SameSite, limitation des tentatives.

## Infrastructure

- Tout tourne dans le k3s du VPS. Manifestes Kustomize dans `infra/k8s/base` et `infra/k8s/overlays/{dev,staging,prod}`.
- Tu as accès seulement aux namespaces `dev` et `staging` (compte de service limité). Ne touche jamais à `prod`.
- Chaque service a : Deployment, Service, probes de santé (`/health`, `/ready`), limites CPU et mémoire, variables par Secret Kubernetes.
- Les secrets Kubernetes sont créés par l'utilisateur ou par `make secrets` à partir de l'environnement ; jamais écrits dans le dépôt.
- Après chaque tâche réussie : `make deploy-staging`, puis `make smoke-staging`. Si le déploiement échoue : `kubectl rollout undo` et note dans BLOCAGES.md.

## Front

- Next.js + TypeScript, composants de `packages/ui`, animations Motion de 150 à 400 ms, désactivées si « réduire les animations ».
- Téléphone d'abord, cibles tactiles ≥ 44 px, contraste ≥ 4,5:1.
- Aucun texte en dur : fichiers de traduction fr et en.

## Commandes

- `make dev` : lance les services Docker et les applications.
- `make test` : tous les tests (Go, front, Playwright, contrat d'API).
- `make lint`, `make security`, `make seed`.
- `make deploy-dev`, `make deploy-staging`, `make smoke-staging`.
