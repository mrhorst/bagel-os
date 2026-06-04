# GitHub Actions CI/CD

This repo uses two separate GitHub Actions workflows:

- `CI` checks pull requests and pushes to `main`.
- `Deploy` runs Kamal only after `CI` succeeds on `main`, or when manually started.

That keeps production deploys behind the same quality gate as pull requests.

## Expected Flow

1. Open a feature branch.
2. Open a pull request.
3. GitHub Actions runs `CI`.
4. Merge to protected `main` after CI passes.
5. `CI` runs again on `main`.
6. `Deploy` runs after that successful `main` CI run.

## GitHub Secrets

Create these repository or environment secrets in GitHub:

```text
KAMAL_APP_HOST
KAMAL_IMAGE
KAMAL_REGISTRY_PASSWORD
KAMAL_REGISTRY_USERNAME
KAMAL_SERVER_IP
KAMAL_SSH_PRIVATE_KEY
KAMAL_SSH_USER
POSTGRES_PASSWORD
RAILS_MASTER_KEY
TASK_BRIEFING_AGENT_GATEWAY_TOKEN
```

Use a dedicated non-interactive deploy SSH key for `KAMAL_SSH_PRIVATE_KEY`.
Do not reuse a personal laptop or Termius key.

## Secret Meanings

- `KAMAL_APP_HOST`: public app host, for example `inventory.example.com`.
- `KAMAL_IMAGE`: full container image name, for example `ghcr.io/OWNER/restaurant-inventory-os`.
- `KAMAL_REGISTRY_USERNAME`: container registry username.
- `KAMAL_REGISTRY_PASSWORD`: container registry password or token.
- `KAMAL_SERVER_IP`: Hetzner server IP address.
- `KAMAL_SSH_PRIVATE_KEY`: private half of the dedicated deploy key.
- `KAMAL_SSH_USER`: server SSH user, usually `root` for the pilot.
- `POSTGRES_PASSWORD`: production Postgres password.
- `RAILS_MASTER_KEY`: contents of `config/master.key`.
- `TASK_BRIEFING_AGENT_GATEWAY_TOKEN`: bearer token for the task briefing agent gateway.

## First Production Run

After secrets are configured, start the `Deploy` workflow manually and choose:

```text
kamal_command = setup
```

After the first setup succeeds, normal merges to `main` should use:

```text
kamal_command = deploy
```

The automatic deploy path always runs `bin/kamal deploy -c config/deploy.github.yml`.

## Branch Protection

Protect `main` in GitHub:

- require pull requests before merging
- require the `CI` workflow to pass
- block direct pushes to `main`
- optionally require the `production` environment approval before deploy

The deploy workflow is intentionally separate from CI. If CI fails, deploy does
not run.
