# GitHub Actions CI/CD

This repo uses two separate GitHub Actions workflows:

- `CI` checks pull requests and pushes to `main`.
- `Deploy` runs Kamal. A successful `CI` run on `main` **auto-deploys to
  staging**; **production is a manual, gated promotion**.

That keeps every change behind the same quality gate as pull requests, and gives
you a deployed staging copy to click through before promoting to production.

## Two environments, one VPS

Both installs run on the same server, fully isolated from each other:

| | Production | Staging |
| --- | --- | --- |
| Kamal target | default (no `-d`) | `-d staging` |
| Config | `config/deploy.yml` | `config/deploy.yml` + `config/deploy.staging.yml` |
| Service / containers | `restaurant-inventory-os` | `restaurant-inventory-os-staging` |
| Postgres container | `restaurant-inventory-os-postgres` | `restaurant-inventory-os-staging-postgres` |
| Postgres host bind | `127.0.0.1:5432` | `127.0.0.1:5433` |
| Database | `restaurant_inventory_os_production` | `restaurant_inventory_os_staging` |
| Data dirs | `/var/lib/restaurant-inventory-os/{postgres,storage}` | `/var/lib/restaurant-inventory-os-staging/{postgres,storage}` |
| Image repo | `KAMAL_IMAGE` | `KAMAL_STAGING_IMAGE` |
| Host | `KAMAL_APP_HOST` | `KAMAL_STAGING_APP_HOST` |
| Deploy trigger | manual `workflow_dispatch` | auto on green `main` CI |

## Expected Flow

1. Open a feature branch, open a pull request.
2. GitHub Actions runs `CI`.
3. Merge to protected `main` after CI passes.
4. `CI` runs again on `main`.
5. `Deploy` runs the **staging** job automatically after that successful run.
6. Click through staging. When happy, **promote to production**: start the
   `Deploy` workflow manually with `destination = production`.

## GitHub Secrets

Shared by both environments:

```text
KAMAL_REGISTRY_PASSWORD
KAMAL_REGISTRY_USERNAME
KAMAL_SERVER_IP
KAMAL_SSH_PRIVATE_KEY
KAMAL_SSH_USER
KAMAL_SSH_KNOWN_HOSTS
RAILS_MASTER_KEY
TASK_BRIEFING_AGENT_GATEWAY_TOKEN
```

Production only:

```text
KAMAL_APP_HOST
KAMAL_IMAGE
POSTGRES_PASSWORD
```

Staging only:

```text
KAMAL_STAGING_APP_HOST
KAMAL_STAGING_IMAGE
STAGING_POSTGRES_PASSWORD
```

Use a dedicated non-interactive deploy SSH key for `KAMAL_SSH_PRIVATE_KEY`.
Do not reuse a personal laptop or Termius key.

## Secret Meanings

- `KAMAL_APP_HOST` / `KAMAL_STAGING_APP_HOST`: public host for each install,
  for example `app.example.com` and `staging.app.example.com`.
- `KAMAL_IMAGE` / `KAMAL_STAGING_IMAGE`: full container image name per install.
  Use a **separate image repo** for staging (same registry, different name) so
  the two never share image labels — for example
  `ghcr.io/OWNER/restaurant-inventory-os` and
  `ghcr.io/OWNER/restaurant-inventory-os-staging`.
- `KAMAL_REGISTRY_USERNAME` / `KAMAL_REGISTRY_PASSWORD`: registry credentials
  (shared — one account, two repos).
- `KAMAL_SERVER_IP`: VPS IP address (shared — both installs live here).
- `KAMAL_SSH_PRIVATE_KEY` / `KAMAL_SSH_USER` / `KAMAL_SSH_KNOWN_HOSTS`: the
  pinned deploy SSH key, user, and known-hosts entry.
- `POSTGRES_PASSWORD` / `STAGING_POSTGRES_PASSWORD`: Postgres password for each
  install. **These must differ** — staging runs its own Postgres container.
- `RAILS_MASTER_KEY`: contents of `config/master.key` (shared — same encrypted
  credentials).
- `TASK_BRIEFING_AGENT_GATEWAY_TOKEN`: bearer token for the task briefing agent
  gateway (shared).

### How secrets resolve

Kamal reads `.kamal/secrets-common` plus a per-target file:

- Production (no destination) → `.kamal/secrets-common` + `.kamal/secrets`
- Staging (`-d staging`) → `.kamal/secrets-common` + `.kamal/secrets.staging`

`RAILS_MASTER_KEY` lives in `.kamal/secrets-common` and works both locally
(reads `config/master.key`) and in CI (falls back to the `RAILS_MASTER_KEY` env
var, since the key is not in the checkout). None of these files hold literal
secret values.

## First Staging Run

After secrets and DNS are in place, start the `Deploy` workflow manually with:

```text
destination   = staging
kamal_command = setup
```

`setup` installs Docker when needed, boots the staging Postgres accessory, and
deploys the app. After it succeeds, every green `main` CI run redeploys staging
automatically. Then seed demo data and create an admin (see the Hetzner doc).

## Promote To Production

Production never deploys automatically. To ship the current `main` to prod:

1. `Deploy` workflow → **Run workflow** → `destination = production`,
   `kamal_command = deploy` (use `setup` only for the very first prod boot).
2. If the `production` environment has required reviewers, approve the run.

The deploy command per target:

```text
staging     bin/kamal deploy -d staging -c config/deploy.yml
production  bin/kamal deploy -c config/deploy.yml
```

## Branch Protection & Environments

Protect `main` in GitHub:

- require pull requests before merging
- require the `CI` workflow to pass
- block direct pushes to `main`

Under **Settings → Environments**:

- `production`: add **required reviewers** so prod promotion needs an approval.
- `staging`: no protection needed (auto-deploy is the point).

The deploy workflow is intentionally separate from CI. If CI fails, deploy does
not run.
