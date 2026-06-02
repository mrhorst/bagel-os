# Hetzner + Kamal Pilot Deployment

This is the small first production setup:

- one Hetzner Ubuntu server
- Kamal deploys the Rails app container
- Postgres runs as a Kamal accessory on the same server
- Active Storage files live on persistent host storage
- Solid Cache, Queue, and Cable keep their existing SQLite files under the same persistent storage mount

## 1. Create The Server

Create a small Hetzner Cloud server with Ubuntu. For the pilot, choose at least
2 GB RAM; 4 GB is more comfortable for Rails plus Postgres.

Point a DNS `A` record, such as `inventory.example.com`, at the server IP.

## 2. Prepare Local Secrets

Set shell variables before running Kamal:

```sh
export KAMAL_REGISTRY_PASSWORD="..."
export POSTGRES_PASSWORD="$(openssl rand -hex 24)"
```

`.kamal/secrets` reads `RAILS_MASTER_KEY` from `config/master.key` and reads the
other values from your shell. Do not commit literal secret values.

## 3. Fill In Kamal Placeholders

Edit `config/deploy.yml`:

- replace `YOUR_SERVER_IP`
- replace `inventory.example.com`
- replace `your-registry-user/restaurant-inventory-os`
- replace `your-registry-user`

## 4. Boot And Deploy

```sh
bin/kamal setup
```

`bin/kamal setup` installs Docker when needed, boots configured accessories, and
deploys the app. Future deploys can use:

```sh
bin/kamal deploy
```

If `bin/kamal` is not available yet, run `bundle install` after the Kamal gem is
installed in the project.

## 5. Create The First Owner

```sh
bin/kamal app exec --interactive --reuse \
  "bin/rails admin:create EMAIL=owner@example.com PASSWORD='long-random-password' NAME='Owner'"
```

The first created admin becomes the owner. Later admins do not take ownership.

## 6. Backups

For the early pilot, enable Hetzner snapshots or backups on the server.

The important host paths are:

```text
/var/lib/restaurant-inventory-os/postgres
/var/lib/restaurant-inventory-os/storage
```

Losing a few hours of pilot data may be acceptable, but losing these folders
means losing database rows and uploaded task photos.

## 7. Email

Password reset email is optional for the first pilot. If you enable SMTP, set
these env vars and add them to `env.secret` in `config/deploy.yml`:

```text
SMTP_ADDRESS
SMTP_PORT
SMTP_USERNAME
SMTP_PASSWORD
```
