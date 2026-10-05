# Décisions déjà prises

Claude ne pose pas de question pour ce qui est listé ici. Pour toute autre décision,
il choisit l'option la plus simple qui respecte OBJECTIF.md, l'ajoute à la fin de ce fichier
avec une phrase d'explication, et continue.

## Produit

- Nom provisoire dans le code et l'interface : « Plateforme » (variable `APP_NAME`, remplaçable plus tard).
- Langue par défaut : français ; tous les textes passent par des fichiers de traduction (fr, en).
- Devise par défaut : XOF (FCFA), montants en entiers, sans décimales.
- Fuseau horaire par défaut : Africa/Dakar.
- Format des téléphones : international (E.164), Sénégal (+221) par défaut.
- TVA par défaut : 18 %, prix affichés TTC, modifiable par vendeur.
- Sous-domaine des boutiques : `<boutique>.<APP_DOMAIN>`.

## Technique

- Go : dernière version stable, routeur chi, sqlc, goose, pas d'ORM.
- Front : Next.js (App Router) + TypeScript + Motion, pnpm, image Docker « standalone » servie dans Kubernetes.
- Base : PostgreSQL, une base, Row Level Security sur `vendeur_id`.
- Événements : Kafka (Redpanda en local), JSON avec schéma dans `contracts/events/`.
- Cache et limites d'appels : Redis.
- Emails en local : Mailpit. En test/production : Amazon SES.
- Fichiers en local : dossier `./data/uploads`. En test/production : Cloudflare R2.
- Identifiants : UUID v7.
- Authentification : sessions en cookies HttpOnly + clés API (publique / secrète) pour l'API publique.
- Tests de navigateur : Playwright. Tests de charge : k6.

## Infrastructure (tout chez nous)

- Un VPS sous k3s (Kubernetes léger), un seul nœud au départ.
- Namespaces : `dev` (tests de la boucle), `staging` (serveur de test public), `prod` (production, interdit à la boucle).
- Entrée HTTP : Traefik (inclus dans k3s) + cert-manager avec Let's Encrypt ; certificat joker pour les boutiques via le DNS Cloudflare.
- Cloudflare sert seulement de DNS (et de CDN optionnel), plus d'hébergement chez eux.
- Images Docker : registre privé dans le cluster (`registry.local:5000`).
- PostgreSQL : opérateur CloudNativePG dans le cluster, sauvegardes vers un stockage S3 (R2 ou autre).
- Redis : StatefulSet simple dans le cluster.
- Kafka : ton serveur Kafka séparé pour `staging` et `prod` ; Redpanda dans `dev` pour les tests.
- Manifestes : Kustomize dans `infra/k8s/` (base + overlays dev, staging, prod). Pas de Helm pour notre code.
- Déploiement : `make deploy-staging` = construire les images, les pousser au registre, `kubectl apply -k`, attendre le rollout, tests de fumée.
- Surveillance : Prometheus + Grafana légers, alertes sur pods en échec, disque et mémoire.

## Services externes absents

- Si une clé manque, utiliser l'implémentation `simulated` du service, cocher la tâche `- [~]`,
  et noter dans BLOCAGES.md : « clé X manquante, fonctionne en mode simulé ». Ne jamais s'arrêter pour ça.
- Ne jamais inventer de vraies clés, ne jamais appeler un service réel sans clé de test fournie.

## Interdits

- Pas d'appel à un service de paiement en mode réel (live) : uniquement sandbox ou simulé.
- Pas de déploiement en production : uniquement sur le serveur de test.
- Pas de lecture ni d'écriture des fichiers `.env` ; le code lit les variables d'environnement.
- Pas de suppression de l'historique git, pas de `git push --force`.

## Décisions ajoutées par Claude

<!-- Claude ajoute ici chaque nouvelle décision, une ligne par décision, avec la date. -->
