# Hetzner + Kamal Pilot Deployment

This is the small first production setup, now with a staging copy alongside it:

- one Hetzner Ubuntu server hosting **both** production and staging
- Kamal deploys the Rails app container (production: default target; staging:
  `-d staging`)
- each install runs its own Postgres accessory on the same server
- Active Storage files live on persistent host storage
- Solid Cache, Queue, and Cable keep their SQLite files under the same mount

Staging is fully isolated from production (separate containers, database, ports,
and data directories) — see `docs/deployment/github-actions-cicd.md` for the
side-by-side table.

## 1. Create The Server

Create a small Hetzner Cloud server with Ubuntu. Running production + staging +
two Postgres containers comfortably wants 4 GB RAM (8 GB is safer once staging
sees real use).

Point DNS `A` records at the server IP — one per install, for example
`app.example.com` (production) and `staging.app.example.com` (staging). Both
records point at the same IP; kamal-proxy routes by host and provisions a
Let's Encrypt cert for each.

## 2. Configure Secrets

The Kamal config reads install-specific values (server IP, host, image,
registry) from environment variables, so nothing identifiable is committed.
Secrets resolve from `.kamal/secrets-common` plus `.kamal/secrets` (production)
or `.kamal/secrets.staging` (staging). `RAILS_MASTER_KEY` comes from
`config/master.key` locally and from the env var in CI. Never commit literal
secret values.

For local Kamal ops, export the same vars the CI workflow sets:

```sh
# shared + production
export KAMAL_SERVER_IP="..." \
  KAMAL_REGISTRY_USERNAME="..." KAMAL_REGISTRY_PASSWORD="..." \
  KAMAL_IMAGE="registry/owner/restaurant-inventory-os" \
  KAMAL_APP_HOST="app.example.com" \
  POSTGRES_PASSWORD="$(openssl rand -hex 24)"

# staging (different image repo, host, and DB password)
export KAMAL_STAGING_IMAGE="registry/owner/restaurant-inventory-os-staging" \
  KAMAL_STAGING_APP_HOST="staging.app.example.com" \
  STAGING_POSTGRES_PASSWORD="$(openssl rand -hex 24)"
```

In GitHub Actions these are repository/environment secrets — see the CI/CD doc.

## 3. No Placeholders To Edit

`config/deploy.yml` (production base) and `config/deploy.staging.yml` (staging
overrides) are entirely env-driven. There is nothing to hand-edit before
deploying — set the environment variables in step 2 and go.

## 4. Boot And Deploy

```sh
# production
bin/kamal setup                  # first boot: installs Docker, accessories, app
bin/kamal deploy                 # subsequent deploys

# staging
bin/kamal setup -d staging       # first boot for staging
bin/kamal deploy -d staging      # subsequent deploys
```

In normal operation CI handles these: green `main` → auto staging deploy;
production is a manual promotion from the `Deploy` workflow.

If `bin/kamal` is not available yet, run `bundle install`.

## 5. Seed And Create The First Owner

Production starts empty. Staging can load generic, non-private demo data:

```sh
# staging: load demo suppliers, items, order guides, tasks (idempotent)
bin/kamal seed_demo -d staging

# create the first owner admin — inline args go inside the quoted command:
bin/kamal app exec -d staging --interactive --reuse \
  "bin/rails admin:create EMAIL=owner@example.com PASSWORD='long-random-password' NAME='Owner'"

# production (same, without -d staging)
bin/kamal app exec --interactive --reuse \
  "bin/rails admin:create EMAIL=owner@example.com PASSWORD='long-random-password' NAME='Owner'"
```

The first created admin becomes the owner. Later admins do not take ownership.
`seed_demo` runs `db:seed` with `SEED_DEMO_DATA=true`; never run it against
production.

## 6. Backups

For the early pilot, enable Hetzner snapshots or backups on the server.

The important host paths are:

```text
/var/lib/restaurant-inventory-os/postgres
/var/lib/restaurant-inventory-os/storage
/var/lib/restaurant-inventory-os-staging/postgres
/var/lib/restaurant-inventory-os-staging/storage
```

Production data is the one that matters; staging is reproducible from
`seed_demo`. Losing the production folders means losing database rows and
uploaded task photos.

## 7. Email

Password reset email is optional for the first pilot. If you enable SMTP, set
these env vars and add them to `env.secret` in `config/deploy.yml`:

```text
SMTP_ADDRESS
SMTP_PORT
SMTP_USERNAME
SMTP_PASSWORD
```
