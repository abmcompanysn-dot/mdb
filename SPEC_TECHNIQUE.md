# Spécification technique — base du projet

Ce document décrit précisément la base à construire (Phase 0 de TACHES.md).
Il complète OBJECTIF.md, CLAUDE.md et DECISIONS.md. En cas de doute, DECISIONS.md fait foi.

---

## 1. Outils et versions

| Outil | Version |
| --- | --- |
| Go | dernière version stable |
| Node.js | dernière LTS |
| pnpm | dernière version, workspaces |
| Next.js | dernière version stable, App Router, TypeScript strict |
| PostgreSQL | 17 |
| Redis | 7 |
| Kafka | Redpanda (image `redpandadata/redpanda`) en local et dans `dev` |
| Emails locaux | Mailpit (image `axllent/mailpit`) |
| Kubernetes | k3s (Traefik inclus), Kustomize |

Bibliothèques Go : `go-chi/chi/v5`, `jackc/pgx/v5`, `sqlc`, `pressly/goose/v3`, `log/slog` (standard),
`twmb/franz-go` (Kafka), `redis/go-redis/v9`, `alexedwards/argon2id` (ou `golang.org/x/crypto/argon2`),
`google/uuid` (UUID v7), `stretchr/testify` pour les tests.

Bibliothèques front : `motion`, `next-intl`, `openapi-typescript` + `openapi-fetch`, `@playwright/test`, `vitest`.

---

## 2. Arborescence complète attendue

```text
plateforme/
├── Makefile
├── go.work
├── package.json                 # workspace pnpm racine
├── pnpm-workspace.yaml
├── .editorconfig
├── .gitignore                   # .env, logs/, STOP, data/, node_modules/, .next/, bin/
├── OBJECTIF.md  TACHES.md  DECISIONS.md  CLAUDE.md  SPEC_TECHNIQUE.md
├── JOURNAL.md  BLOCAGES.md  env.example  boucle.sh  prompts/boucle.md
├── .claude/settings.json
├── backend/
│   ├── go.mod
│   ├── sqlc.yaml
│   ├── cmd/
│   │   ├── api/main.go
│   │   └── worker/main.go
│   ├── internal/
│   │   ├── platform/
│   │   │   ├── config/config.go        # lecture des variables d'environnement
│   │   │   ├── db/db.go                # pool pgx, transaction avec vendeur_id
│   │   │   ├── httpx/                  # routeur, middlewares, erreurs JSON, pagination
│   │   │   ├── logx/logx.go            # slog JSON
│   │   │   ├── redisx/redisx.go
│   │   │   └── security/               # hachage, jetons, chiffrement AES-GCM
│   │   ├── events/
│   │   │   ├── envelope.go             # format commun des événements
│   │   │   ├── outbox.go               # écriture dans la table outbox
│   │   │   ├── relay.go                # outbox -> Kafka
│   │   │   └── consumer.go             # lecture idempotente
│   │   └── account/
│   │       ├── queries.sql             # requêtes sqlc
│   │       ├── store.go                # code généré + accès
│   │       ├── service.go              # logique métier
│   │       ├── handlers.go             # routes HTTP
│   │       └── account_test.go
│   └── migrations/
│       └── 00001_fondations.sql
├── web/
│   ├── dashboard/                      # Next.js
│   │   ├── app/[locale]/(auth)/inscription/page.tsx
│   │   ├── app/[locale]/(auth)/connexion/page.tsx
│   │   ├── app/[locale]/(auth)/mot-de-passe/page.tsx
│   │   ├── app/[locale]/tableau-de-bord/page.tsx
│   │   ├── messages/fr.json  messages/en.json
│   │   ├── lib/api.ts                  # client généré depuis openapi.yaml
│   │   ├── e2e/inscription.spec.ts     # Playwright
│   │   └── Dockerfile
│   └── storefront/                     # squelette Next.js vide + Dockerfile
├── packages/
│   ├── ui/                             # design system
│   │   ├── src/tokens.ts
│   │   ├── src/motion.ts
│   │   ├── src/components/{Button,Input,Card,Toast,Badge,Skeleton}.tsx
│   │   └── src/index.ts
│   └── sdk/                            # squelette, rempli en version 4
├── contracts/
│   ├── openapi.yaml
│   └── events/
│       ├── envelope.schema.json
│       └── compte.cree.v1.schema.json
├── infra/
│   ├── docker-compose.yml
│   ├── preparer-vps.sh
│   ├── docker/{api,worker}.Dockerfile
│   └── k8s/
│       ├── base/{kustomization.yaml,namespace-agnostic manifests...}
│       └── overlays/{dev,staging,prod}/kustomization.yaml
└── .github/workflows/ci.yml
```

---

## 3. Makefile (cibles obligatoires)

| Cible | Effet |
| --- | --- |
| `make dev` | `docker compose -f infra/docker-compose.yml up -d`, migrations, lance api + worker + dashboard en mode développement |
| `make migrate` | applique les migrations goose sur `DATABASE_URL` |
| `make sqlc` | régénère le code Go depuis les requêtes |
| `make test` | démarre les services si besoin, puis `go test ./...`, `pnpm -r test`, tests Playwright, vérification du contrat d'API ; code de sortie ≠ 0 si un seul échoue |
| `make lint` | `gofmt -l`, `go vet`, `golangci-lint` si présent, `pnpm -r lint`, `kubeconform` sur les overlays |
| `make security` | `govulncheck ./...`, `gosec ./...`, `pnpm audit --prod` |
| `make images` | construit les images `api`, `worker`, `dashboard`, `storefront` taguées `$(REGISTRY)/<nom>:$(GIT_SHA)` |
| `make deploy-dev` / `make deploy-staging` | `make images`, push au registre, `kubectl apply -k infra/k8s/overlays/<env>`, `kubectl rollout status` |
| `make smoke-staging` | `curl -fsS https://api.test.$(APP_DOMAIN)/health` (ou via port-forward si pas de DNS) |
| `make seed` | données de démonstration |

---

## 4. docker-compose (tests rapides en local)

| Service | Image | Port |
| --- | --- | --- |
| postgres | `postgres:17` (utilisateur, mot de passe et base : `plateforme`) | 5432 |
| redis | `redis:7` | 6379 |
| redpanda | `redpandadata/redpanda` en mode développement, un nœud | 9092 |
| mailpit | `axllent/mailpit` | 1025 (SMTP), 8025 (web) |

Chaque service a un `healthcheck`. `make test` attend qu'ils soient sains.

---

## 5. Backend Go

### Configuration

Une structure `Config` remplie depuis l'environnement (voir `env.example`), avec valeurs par défaut pour le développement.
Démarrage refusé si `APP_ENV` vaut `staging` ou `production` et qu'un secret obligatoire est vide.

### HTTP

- Préfixe de l'API : `/v1`. Routes techniques hors préfixe : `GET /health` (vivant), `GET /ready` (base + Redis + Kafka joignables).
- Middlewares dans cet ordre : identifiant de requête, journal, récupération de panique, CORS (origines configurées), limitation d'appels (Redis), authentification, vendeur courant.
- Format d'erreur unique :

```json
{ "error": { "code": "email_deja_utilise", "message": "Cet email est déjà utilisé.", "request_id": "..." } }
```

- Pagination par curseur : `?limit=20&cursor=...`, réponse `{ "data": [...], "next_cursor": "..." }`.
- Montants : entiers + devise, ex. `{ "amount": 18500, "currency": "XOF" }`.

### Authentification (Phase 0)

| Route | Corps | Réponse |
| --- | --- | --- |
| `POST /v1/auth/signup` | `{ email, password, full_name, store_name }` | 201 + cookie de session ; crée vendeur + utilisateur propriétaire ; publie `compte.créé` |
| `POST /v1/auth/login` | `{ email, password }` | 200 + cookie ; 429 après 5 échecs en 15 min |
| `POST /v1/auth/logout` | — | 204, session supprimée |
| `POST /v1/auth/password/forgot` | `{ email }` | 202 toujours (ne révèle pas si l'email existe) ; email avec lien valable 1 h |
| `POST /v1/auth/password/reset` | `{ token, password }` | 204 |
| `GET /v1/me` | — | `{ user, vendeur, role }` |

- Mots de passe : argon2id, 10 caractères minimum.
- Cookie `session` : HttpOnly, Secure (hors développement), SameSite=Lax, 30 jours glissants. Jeton aléatoire 32 octets ; seul son hachage SHA-256 est stocké.
- Protection CSRF : en-tête `X-CSRF-Token` exigé sur toute requête qui modifie des données avec cookie.
- Clés API (préparées, utilisées en version 4) : `pk_test_…` / `sk_test_…`, seul le hachage est stocké.

---

## 6. Base de données — migration `00001_fondations.sql`

```sql
-- +goose Up
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE vendeurs (
  id          uuid PRIMARY KEY,
  nom         text NOT NULL,
  slug        text NOT NULL UNIQUE,          -- sous-domaine de la boutique
  forfait     text NOT NULL DEFAULT 'gratuit',
  devise      char(3) NOT NULL DEFAULT 'XOF',
  fuseau      text NOT NULL DEFAULT 'Africa/Dakar',
  statut      text NOT NULL DEFAULT 'actif', -- actif, suspendu
  cree_le     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE utilisateurs (
  id             uuid PRIMARY KEY,
  email          citext NOT NULL UNIQUE,
  nom_complet    text NOT NULL,
  mot_de_passe   text NOT NULL,              -- hachage argon2id
  super_admin    boolean NOT NULL DEFAULT false,
  cree_le        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE membres (                       -- lien utilisateur <-> vendeur avec rôle
  vendeur_id     uuid NOT NULL REFERENCES vendeurs(id),
  utilisateur_id uuid NOT NULL REFERENCES utilisateurs(id),
  role           text NOT NULL,              -- proprietaire, admin, commandes, marketing, formateur, support
  PRIMARY KEY (vendeur_id, utilisateur_id)
);

CREATE TABLE sessions (
  id_hash        bytea PRIMARY KEY,          -- SHA-256 du jeton
  utilisateur_id uuid NOT NULL REFERENCES utilisateurs(id),
  vendeur_id     uuid NOT NULL REFERENCES vendeurs(id),
  expire_le      timestamptz NOT NULL,
  cree_le        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE jetons_reinitialisation (
  jeton_hash     bytea PRIMARY KEY,
  utilisateur_id uuid NOT NULL REFERENCES utilisateurs(id),
  expire_le      timestamptz NOT NULL,
  utilise_le     timestamptz
);

CREATE TABLE cles_api (
  id          uuid PRIMARY KEY,
  vendeur_id  uuid NOT NULL REFERENCES vendeurs(id),
  type        text NOT NULL,                 -- publique, secrete
  prefixe     text NOT NULL,                 -- pk_test_abcd (affichage)
  cle_hash    bytea NOT NULL UNIQUE,
  revoquee_le timestamptz,
  cree_le     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE outbox (                         -- événements à publier dans Kafka
  id          uuid PRIMARY KEY,
  vendeur_id  uuid NOT NULL,
  type        text NOT NULL,
  charge      jsonb NOT NULL,
  cree_le     timestamptz NOT NULL DEFAULT now(),
  publie_le   timestamptz
);
CREATE INDEX outbox_non_publie ON outbox (cree_le) WHERE publie_le IS NULL;

CREATE TABLE evenements_traites (             -- idempotence des consommateurs
  consommateur text NOT NULL,
  evenement_id uuid NOT NULL,
  traite_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (consommateur, evenement_id)
);

-- Séparation des vendeurs : chaque requête métier fait d'abord
-- SET LOCAL app.vendeur_id = '<uuid>' dans sa transaction.
ALTER TABLE membres  ENABLE ROW LEVEL SECURITY;
ALTER TABLE cles_api ENABLE ROW LEVEL SECURITY;
CREATE POLICY isolation_vendeur ON membres
  USING (vendeur_id = current_setting('app.vendeur_id', true)::uuid);
CREATE POLICY isolation_vendeur ON cles_api
  USING (vendeur_id = current_setting('app.vendeur_id', true)::uuid);

-- +goose Down
DROP TABLE evenements_traites, outbox, cles_api, jetons_reinitialisation, sessions, membres, utilisateurs, vendeurs;
```

Règles :

- L'application se connecte avec un rôle PostgreSQL **sans** `BYPASSRLS` ; les migrations avec un rôle propriétaire distinct.
- Toute nouvelle table métier : colonne `vendeur_id`, RLS activée, politique `isolation_vendeur`, test d'isolation.
- `db.WithVendeur(ctx, vendeurID, func(tx) error)` ouvre la transaction et fait le `SET LOCAL`.

---

## 7. Événements Kafka

### Enveloppe commune (`contracts/events/envelope.schema.json`)

```json
{
  "id": "uuid v7",
  "type": "compte.créé",
  "version": 1,
  "vendeur_id": "uuid",
  "occurred_at": "2026-10-05T12:00:00Z",
  "data": { }
}
```

- Sujets : un par domaine, `plateforme.<domaine>.v1` (ex. `plateforme.comptes.v1`, `plateforme.commandes.v1`).
- Clé de partition : `vendeur_id` (ordre garanti par vendeur).
- Publication : jamais directement depuis une route HTTP. La route écrit dans `outbox` dans la même transaction
  que la donnée ; le relais (dans le worker) publie puis remplit `publie_le`. Aucun événement perdu.
- Consommation : un groupe de consommateurs par usage (`emails`, `stats`, `meta`…). Avant traitement,
  insertion dans `evenements_traites` ; si la ligne existe déjà, l'événement est ignoré.
- Échecs : 3 essais avec attente croissante, puis envoi dans `plateforme.erreurs.v1` avec la raison.

---

## 8. Front

### Design system (`packages/ui`)

```ts
export const colors = {
  encre: '#0D1117', surface: '#161B22', bordure: '#2A313B',
  safran: '#F2A33A', safranTexte: '#A85A00', lagune: '#3CCFB4',
  sable: '#F3F1EC', brume: '#A9B1BC', fondClair: '#F5F6F8', texte: '#12161D', texteDoux: '#5B6472',
};
export const fonts = { titre: "'Bricolage Grotesque', system-ui, sans-serif", texte: "'DM Sans', system-ui, sans-serif", code: "'JetBrains Mono', monospace" };
export const motion = { rapide: 0.15, standard: 0.25, page: 0.4, celebration: 0.8, courbe: [0.2, 0.7, 0.2, 1] };
```

- Toutes les animations passent par `motion` et sont coupées si `prefers-reduced-motion`.
- Composants de base : Button (primaire safran, secondaire, fantôme), Input + Label, Card, Toast, Badge, Skeleton.
- Cibles tactiles ≥ 44 px, contraste ≥ 4,5:1, boutons et liens réels (`<button>`, `<a>`).

### Tableau de bord (`web/dashboard`)

- Langues : `fr` (défaut) et `en` avec `next-intl`, URLs `/fr/...`.
- Pages Phase 0 : inscription, connexion, mot de passe oublié, tableau de bord vide (« Bonjour, ajoute ton premier produit »).
- Client API généré depuis `contracts/openapi.yaml` ; cookies envoyés avec `credentials: 'include'`, jeton CSRF ajouté automatiquement.
- Build `output: 'standalone'` pour l'image Docker.

---

## 9. Images Docker

- Go : construction multi-étapes, image finale `gcr.io/distroless/static-debian12:nonroot`, binaire statique.
- Next.js : `node:lts-alpine`, sortie `standalone`, utilisateur non root, port 3000.
- Aucune clé dans les images ; tout par variables d'environnement.

---

## 10. Kubernetes (`infra/k8s`)

- `base/` : Deployments `api`, `worker`, `dashboard`, `storefront` ; Services ; ConfigMap `plateforme-config` ;
  références au Secret `plateforme-secrets` (créé hors dépôt) ; Ingress de classe `traefik`.
- Chaque Deployment : `readinessProbe` sur `/ready`, `livenessProbe` sur `/health`, `resources.requests/limits`,
  `securityContext` non root, `readOnlyRootFilesystem: true`.
- Overlays :
  - `dev` : 1 réplica, Redpanda + PostgreSQL + Redis dans le namespace.
  - `staging` : 1 à 2 réplicas, hôtes `test.<domaine>`, `api.test.<domaine>`, `*.test.<domaine>`, Kafka externe (ton serveur).
  - `prod` : 2 réplicas minimum, hôtes de production ; appliqué uniquement par toi.
- PostgreSQL : ressource `Cluster` de CloudNativePG (1 instance au départ), sauvegardes S3 si configurées.
- Certificats : cert-manager, `ClusterIssuer` Let's Encrypt, DNS-01 Cloudflare pour le joker.

---

## 11. Intégration continue (`.github/workflows/ci.yml`)

À chaque push : installation Go + Node + pnpm, services PostgreSQL / Redis / Redpanda / Mailpit,
`make lint`, `make test`. Pas de déploiement depuis GitHub : le déploiement se fait sur le VPS par `make deploy-staging`.

---

## 12. Définition de « terminé » pour la base

- `make dev` démarre tout, `make test` est vert, `make lint` est vert.
- Parcours Playwright : s'inscrire → arriver sur le tableau de bord → se déconnecter → se reconnecter.
- Un test prouve qu'un vendeur A ne voit jamais les lignes du vendeur B.
- Un test prouve que `compte.créé` passe par l'outbox, arrive dans Kafka, et n'est traité qu'une fois même lu deux fois.
- `kubectl kustomize infra/k8s/overlays/{dev,staging,prod}` réussit et `kubeconform` valide.
