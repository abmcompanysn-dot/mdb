# Objectif — Version 1 de la plateforme

Construire la version 1 d'une plateforme tout-en-un (boutique type Shopify + marketing type Systeme.io)
pour les vendeurs d'Afrique de l'Ouest francophone.

À la fin, sur le serveur de test :

1. Un vendeur s'inscrit, se connecte, et choisit un forfait (Gratuit, Mini, Démarrage, Pro, Business).
2. Il ajoute des produits avec variantes, stocks et photos.
3. Sa boutique publique est en ligne sur un sous-domaine, rapide sur téléphone.
4. Un client remplit son panier et paie avec Wave, Orange Money, carte bancaire ou à la livraison.
5. Le vendeur gère ses commandes : statuts, factures PDF, livraison, remboursements.
6. Chaque commande payée déclenche automatiquement un email au client et un événement Kafka.
7. Le vendeur crée une page de vente simple avec l'éditeur.
8. Le vendeur connecte Facebook en un clic : pixel et API de conversions envoient les ventes à Meta.
9. Le vendeur paie son abonnement en Wave ; les limites de son forfait s'appliquent.
10. Un super administrateur voit tous les vendeurs, leurs forfaits et peut suspendre un compte.
11. Le tableau de bord vendeur montre chiffre d'affaires, commandes et moyens de paiement.

Contraintes :

- Backend et logique métier en Go. Front Next.js. Événements dans Kafka.
- Tout est hébergé chez nous : un VPS sous Kubernetes (k3s) qui sert à la fois au développement,
  au serveur de test (namespace `staging`) et plus tard à la production (namespace `prod`, fermé à la boucle).
- Toute la logique passe par l'API publique décrite dans `contracts/openapi.yaml`.
- Interface en français (anglais prévu), montants en FCFA (XOF), téléphone d'abord.
- Design « Dakar de nuit » : encre #0D1117, safran #F2A33A, lagune #3CCFB4, sable #F3F1EC,
  typographies Bricolage Grotesque (titres) et DM Sans (texte), animations courtes (150 à 400 ms).
- Tout fonctionne en mode simulé si une clé externe manque ; les vraies clés se branchent ensuite sans changer le code.

La version 1 est terminée quand toutes les tâches de `TACHES.md` sont cochées et que `make test` passe entièrement.
