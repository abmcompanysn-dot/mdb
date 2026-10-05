# Tâches — Version 1

Légende : `- [ ]` à faire · `- [x]` fait · `- [~]` fait en mode simulé (clé externe manquante, à brancher plus tard)
Chaque tâche n'est cochée que si son critère « Terminé quand » est prouvé par un test automatique.

## Phase 0 — Fondations

- [ ] P0.1 Structure du monorepo (backend/, web/, packages/, contracts/, infra/, .github/) et Makefile avec `make dev`, `make test`, `make lint` — Terminé quand : `make test` s'exécute sans erreur sur un dépôt vide de tests.
- [ ] P0.2 `infra/docker-compose.yml` avec PostgreSQL, Redis, Redpanda (compatible Kafka) et Mailpit (emails de test) — Terminé quand : `make dev` démarre les 4 services et un test vérifie qu'ils répondent.
- [ ] P0.3 Squelette Go `backend/cmd/api` : configuration par variables d'environnement, journaux structurés, route `GET /health` — Terminé quand : un test HTTP reçoit 200 sur `/health`.
- [ ] P0.4 Migrations avec goose et requêtes avec sqlc ; tables `vendeurs`, `utilisateurs`, `roles` avec `vendeur_id` et Row Level Security — Terminé quand : un test prouve qu'un vendeur ne lit jamais les lignes d'un autre.
- [ ] P0.5 Inscription, connexion, déconnexion, mot de passe oublié, sessions sécurisées (cookies HttpOnly), limitation des tentatives — Terminé quand : tests d'intégration des 4 parcours et du blocage après 5 essais.
- [ ] P0.6 Module `events` : publication et lecture Kafka, format décrit dans `contracts/events/`, identifiant unique, `vendeur_id`, file d'erreurs — Terminé quand : un test publie `compte.créé` et le worker le lit une seule fois.
- [ ] P0.7 Squelette Go `backend/cmd/worker` qui consomme les sujets Kafka — Terminé quand : test d'intégration worker + Redpanda.
- [ ] P0.8 `packages/ui` : design system React (couleurs, typographies, boutons, champs, cartes, notifications) avec animations Motion et respect de « réduire les animations » — Terminé quand : tests de rendu des composants.
- [ ] P0.9 `web/dashboard` Next.js : pages inscription, connexion, tableau de bord vide, branchées sur l'API — Terminé quand : test Playwright « s'inscrire puis voir le tableau de bord ».
- [ ] P0.10 `contracts/openapi.yaml` avec les routes existantes, et vérification que l'API respecte le contrat — Terminé quand : test de conformité au contrat.
- [ ] P0.11 Dockerfiles multi-étapes : backend api, worker, dashboard, storefront (Next.js standalone), images < 200 Mo — Terminé quand : `make images` construit les 4 images.
- [ ] P0.12 Kubernetes : `infra/k8s/base` (Deployments, Services, probes, limites, ConfigMaps) et overlays `dev`, `staging`, `prod` avec Kustomize — Terminé quand : `kubectl kustomize` passe pour les 3 overlays et `kubeconform` valide les manifestes.
- [ ] P0.13 Services du cluster : registre d'images local, PostgreSQL (CloudNativePG), Redis, Redpanda dans `dev` — Terminé quand : `make deploy-dev` les démarre et un test de connexion passe depuis un pod.
- [ ] P0.14 Entrée HTTP : Traefik + cert-manager, domaines `test.<APP_DOMAIN>`, `api.test.<APP_DOMAIN>`, joker `*.test.<APP_DOMAIN>` — Terminé quand : manifestes valides ; certificats réels `[~]` tant que le DNS et le jeton Cloudflare ne sont pas fournis.
- [ ] P0.15 `make deploy-staging` et `make smoke-staging` : construire, pousser au registre, appliquer, attendre le rollout, vérifier `/health` — Terminé quand : déploiement réussi dans `staging` et test de fumée vert.
- [ ] P0.16 Intégration continue : lint + tests à chaque commit (GitHub Actions ou script local) — Terminé quand : le workflow est valide (actionlint).
- [ ] P0.17 Surveillance légère : Prometheus, Grafana, alertes (pod en échec, disque > 80 %, mémoire) — Terminé quand : tableau Grafana accessible dans `staging`.
- [ ] P0.18 Sauvegardes : sauvegarde quotidienne PostgreSQL (CloudNativePG) vers un stockage S3, en mode simulé si absent — Terminé quand : restauration testée dans `dev`.

## Sprint 1 — Catalogue

- [ ] S1.1 Tables et API produits : nom, description, prix en entiers XOF, prix barré, SKU, poids, statut (brouillon, publié, archivé) — Terminé quand : tests CRUD + tests de validation.
- [ ] S1.2 Variantes (jusqu'à 3 options, 100 combinaisons) avec prix et stock propres — Terminé quand : tests de génération et de limites.
- [ ] S1.3 Stocks : quantité par variante, historique des mouvements, alerte de seuil (événement `stock.bas`) — Terminé quand : tests de mouvements et d'événement.
- [ ] S1.4 Photos : envoi vers Cloudflare R2 (ou stockage local simulé), redimensionnement WebP — Terminé quand : test d'envoi et de lecture en mode simulé.
- [ ] S1.5 Collections manuelles et catégories — Terminé quand : tests API.
- [ ] S1.6 Écrans du tableau de bord : liste des produits, création, édition, variantes, photos — Terminé quand : test Playwright « créer un produit avec 2 variantes et 1 photo ».
- [ ] S1.7 Import CSV de produits — Terminé quand : test avec un fichier de 50 produits.

## Sprint 2 — Boutique publique et panier

- [ ] S2.1 `web/storefront` : boutique par sous-domaine du vendeur, page d'accueil, collection, fiche produit, thème « Dakar de nuit » clair — Terminé quand : test Playwright sur une boutique de démonstration.
- [ ] S2.2 Pages mises en cache (cache HTTP Next.js + Traefik, CDN Cloudflare optionnel devant) et images optimisées — Terminé quand : score Lighthouse mobile ≥ 90 sur la fiche produit (test automatisé).
- [ ] S2.3 Panier : ajout, quantité, suppression, panier conservé, codes promo (pourcentage, montant fixe, livraison gratuite) — Terminé quand : tests API + Playwright.
- [ ] S2.4 Événements `produit.vu`, `panier.ajout` publiés dans Kafka — Terminé quand : test d'intégration.
- [ ] S2.5 Bouton « Commander sur WhatsApp » avec message prérempli — Terminé quand : test du lien généré.

## Sprint 3 — Paiements

- [ ] S3.1 Interface Go `PaymentProvider` avec 4 implémentations : agrégateur local (Wave, Orange Money, Free Money), Stripe (carte), paiement à la livraison, et `simulated` — Terminé quand : tests de chaque implémentation (simulée si clé absente).
- [ ] S3.2 Checkout en une page, mobile, sans compte obligatoire, champs « quartier » et « point de repère » — Terminé quand : test Playwright complet en mode simulé.
- [ ] S3.3 Webhooks de paiement signés, idempotents (aucune commande en double), état `paiement.commencé` → `commande.payée` — Terminé quand : test qui envoie 3 fois le même webhook et obtient 1 seule commande.
- [ ] S3.4 Échecs de paiement et relance du client — Terminé quand : test de l'événement `paiement.échoué`.
- [ ] S3.5 Tests de bout en bout en sandbox réelle quand les clés de test sont présentes — Terminé quand : test passé en sandbox, sinon `[~]`.

## Sprint 4 — Commandes et livraison

- [ ] S4.1 Commandes : liste filtrable, fiche, statuts (payée, à préparer, expédiée, livrée, annulée), notes internes — Terminé quand : tests API + Playwright.
- [ ] S4.2 Copie du prix et du nom du produit au moment de l'achat — Terminé quand : test qui modifie le produit après la commande.
- [ ] S4.3 Factures PDF générées et stockées — Terminé quand : test de génération.
- [ ] S4.4 Zones et tarifs de livraison (fixe, par poids, gratuite au-delà d'un montant), retrait en boutique — Terminé quand : tests de calcul.
- [ ] S4.5 Remboursement total ou partiel, remise en stock — Terminé quand : tests.
- [ ] S4.6 Création manuelle de commande avec lien de paiement (vente par WhatsApp) — Terminé quand : test.

## Sprint 5 — Emails et contacts

- [ ] S5.1 Worker emails : confirmation de commande, expédition, mot de passe oublié, via Amazon SES ou Mailpit en local — Terminé quand : test qui vérifie l'email reçu dans Mailpit après `commande.payée`.
- [ ] S5.2 Contacts : fiche, champs personnalisés, import/export CSV, désinscription en un clic — Terminé quand : tests.
- [ ] S5.3 Tags et segments simples — Terminé quand : tests.
- [ ] S5.4 Campagne email simple à un tag, avec statistiques d'ouverture et de clic — Terminé quand : test en mode Mailpit.

## Sprint 6 — Pages de vente et Meta

- [ ] S6.1 Éditeur de pages glisser-déposer (sections : titre, texte, image, vidéo, bouton, formulaire, témoignages, FAQ, compte à rebours), aperçu téléphone — Terminé quand : test Playwright « créer et publier une page ».
- [ ] S6.2 Formulaire de capture qui crée un contact et publie `contact.créé` — Terminé quand : test.
- [ ] S6.3 Connexion Facebook en un clic (OAuth), jetons chiffrés côté serveur — Terminé quand : test avec un serveur OAuth simulé ; vrai test `[~]` sans clés Meta.
- [ ] S6.4 Pixel automatique et API de conversions depuis Kafka (ViewContent, AddToCart, InitiateCheckout, Purchase, Lead) avec identifiant commun anti-doublon — Terminé quand : test qui vérifie les requêtes envoyées à un faux serveur Meta.

## Sprint 7 — Forfaits, tableau de bord et administration

- [ ] S7.1 Forfaits (Gratuit, Mini 2 500, Démarrage 5 000, Pro 15 000, Business 35 000 FCFA) et limites (produits, contacts, tunnels, commission) — Terminé quand : tests de chaque limite.
- [ ] S7.2 Paiement de l'abonnement du vendeur en Wave/Orange Money, rappel avant échéance, 7 jours de grâce — Terminé quand : tests avec horloge simulée.
- [ ] S7.3 Tableau de bord vendeur : chiffre d'affaires, commandes, contacts, moyens de paiement, ventes sur 14 jours, animations du design — Terminé quand : test Playwright.
- [ ] S7.4 Domaine personnel du vendeur (instructions DNS, vérification, certificat automatique par cert-manager) — Terminé quand : test en mode simulé.
- [ ] S7.5 Panneau super administrateur : liste des vendeurs, forfaits, suspension, connexion d'aide tracée, statistiques globales — Terminé quand : tests de droits (un vendeur ne peut jamais y accéder).
- [ ] S7.6 Équipes : inviter un collaborateur avec un rôle — Terminé quand : tests de droits.

## Sprint 8 — Qualité et préparation au lancement

- [ ] S8.1 Contrôle de sécurité : dépendances, en-têtes HTTP, injections, droits, limites d'appels — Terminé quand : `make security` passe (gosec, govulncheck, npm audit).
- [ ] S8.2 Tests de charge : 200 visiteurs simultanés sur une boutique — Terminé quand : temps de réponse moyen < 300 ms en local (k6).
- [ ] S8.3 Procédure de restauration complète écrite (base, fichiers, manifestes) et préparation de l'overlay `prod` — Terminé quand : restauration testée dans `dev` et `kubectl kustomize overlays/prod` valide.
- [ ] S8.4 Surveillance : Sentry et métriques Prometheus — Terminé quand : erreur de test visible en mode simulé.
- [ ] S8.5 Documentation : README, guide de déploiement, liste des variables d'environnement — Terminé quand : fichiers présents et à jour.
- [ ] S8.6 Boutique de démonstration complète avec données d'exemple — Terminé quand : `make seed` crée la démo.
