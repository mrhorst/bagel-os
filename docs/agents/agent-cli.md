# Agent CLI (`bin/agent`)

A JSON-emitting command line that lets an agent (AI or human) read and act on
Bagel OS domain data without scraping HTML — the first slice of the "LLM
assistant that answers through structured database queries" direction in
`CONTEXT.md`.

```sh
bin/agent login --email you@example.com   # authenticate first
bin/agent tasks:today                      # pretty JSON
bin/agent price:product "house blend" --compact
```

## Install

The CLI runs from this checkout (it boots the app from here), so "installing"
just puts an `agent` command on your PATH that points back at `bin/agent` — no
copy, no build step.

```sh
bin/install-agent          # symlinks agent into ~/.local/bin
```

Then `agent help` works from any directory. Options:

- `BAGEL_AGENT_BIN_DIR=/usr/local/bin bin/install-agent` — link elsewhere.
- `BAGEL_AGENT_FORCE=1 bin/install-agent` — replace a non-symlink already there.
- Uninstall: `rm "<bin-dir>/agent"`.

Prerequisites: Ruby and the app's gems (`bundle install`). The installer prints
how to add the bin dir to PATH if it isn't already. You can always run
`./bin/agent` directly without installing.

> The rest of this doc writes `bin/agent` for clarity; once installed, `agent`
> is equivalent.

## Local vs. remote (posting to production)

The CLI has two transports, chosen by one environment variable:

- **Local** (default): boots the app from this checkout and talks to its
  database directly. Good for dev and for running on a server.
- **Remote**: set `BAGEL_API_URL` and the CLI sends commands to a running app
  over HTTPS instead of booting Rails. No checkout, gems, DB, or secrets needed
  near the agent — just a URL and a token. This is how an agent posts to
  production from anywhere.

```sh
export BAGEL_API_URL=https://app.example.com
agent login --email you@example.com    # gets a token from the app, stores it
agent tasks:create --list Closing --title "Lock up" --due-time 22:00 --yes
```

The remote transport hits three endpoints on the app:

| Method + path        | Purpose |
| -------------------- | ------- |
| `POST /agent`        | Run a command. Body `{ "argv": [...] }`, `Authorization: Bearer <token>`. |
| `POST /agent/session`| Log in: `{ email, password }` → `{ token, user, environment }`. Rate-limited. |
| `DELETE /agent/session` | Log out: revoke the session (Bearer token). |

Output is byte-for-byte the same envelope as a local run (same `Dispatcher`
backs both), so an agent doesn't care which transport it used. Remote requests
time out after 10s (`BAGEL_AGENT_HTTP_TIMEOUT` to change) and fail with a
`connection_error` envelope instead of hanging. The command endpoint is
rate-limited (120/min) alongside the stricter login limit.

### Production-write guardrail

Every response includes an `environment` field (`development` / `production` /
…) so an agent can confirm where it is before acting. On a **production** app,
mutating commands are refused unless explicitly confirmed:

```json
{ "ok": false, "command": "tasks:create",
  "error": { "type": "confirmation_required",
             "message": "Refusing to run a write against production without confirmation.",
             "hint": "Re-run with --yes (or set BAGEL_AGENT_YES=1) to proceed." } }
```

Reads are never gated. The check is enforced server-side, so it holds no matter
which client connects.

## Authentication

Domain commands require an authenticated session — having the project checked
out grants no data access on its own (this matters now and more so once the app
is multi-tenant). Auth reuses the web app's primitives: `User.authenticate_by`
verifies credentials and a `Session` row is the unit of access. The CLI signs
the session id into a bearer token (Rails' message verifier) and stores it
**outside the repo**, in `~/.config/bagel-os/credentials.json` (mode 0600).

```sh
bin/agent login --email you@example.com    # prompts for password
bin/agent whoami                           # who am I? (never errors)
bin/agent logout                           # revoke session + delete token
```

Token resolution order:

1. `BAGEL_AGENT_TOKEN` env var — for agents/automation; `login --print-token`
   emits a token to put here, no file needed.
2. the credentials file written by `login`.

Password resolution for `login`: `--password`, else `BAGEL_AGENT_PASSWORD`,
else an interactive prompt (preferred — keeps it out of shell history). The
config dir can be relocated with `BAGEL_OS_CONFIG_DIR`.

Tokens expire after **30 days** (override with `BAGEL_AGENT_TOKEN_TTL_DAYS`;
`0` disables expiry) — re-run `login` to mint a fresh one. `logout` revokes the
session immediately, and covers both the env-var token and the file token when
they differ.

`help`, `schema`, `login`, `logout`, and `whoami` are the only commands that
run unauthenticated. Everything else returns `type: "unauthenticated"` (exit 1)
until you log in. The authenticated user is bound to `Current.session` for the
command run — the seam multi-tenancy will extend to scope data by tenant.

## Contract

Every successful command prints one JSON document to **stdout**:

```json
{
  "ok": true,
  "command": "tasks:today",
  "generated_at": "2026-06-27T19:40:12-04:00",
  "data": { "...": "..." }
}
```

Failures print an envelope to **stderr** and exit non-zero (status `1`):

```json
{
  "ok": false,
  "command": "price:product",
  "error": { "type": "not_found", "message": "No product matching \"zzz\"" }
}
```

Error `type` is one of `unknown_command`, `unauthenticated`, `usage_error`,
`not_found`, `ambiguous`, `error`. This split (data on stdout, errors on
stderr, exit codes) lets a caller pipe stdout straight into a JSON parser and
branch on the exit status.

Built for agent consumers, the output is self-describing:

- **Every error carries a `hint`** — a short, actionable next step, usually the
  command to run next. A `not_found` product points at `products:search`; a
  missing list points at `tasks:lists` / `tasks:create-list`; the auth gate
  points at `login`.
- **`ambiguous` errors carry `candidates`** (id + label) so the agent re-runs
  with an exact id instead of guessing.
- **Limited reads report completeness** — commands that take `--limit` return
  `returned`, `limit`, and `truncated`. `truncated: true` means more rows
  exist, so raise `--limit`.

```json
{
  "ok": false,
  "command": "price:product",
  "error": {
    "type": "not_found",
    "message": "No product matching \"zzz\"",
    "hint": "Run `bin/agent products:search \"zzz\"` to see candidates."
  }
}
```

Money and decimal values serialize as **strings** so consumers never inherit
float rounding error on prices.

## Global options

| Option        | Effect                              |
| ------------- | ----------------------------------- |
| `--compact`   | Single-line JSON instead of pretty  |
| `--dry-run`   | On a mutating command, resolve and report what *would* happen without writing |
| `--yes`       | Confirm a mutating command against a production app (`BAGEL_AGENT_YES=1` equivalent) |
| `--help`, `-h`| Print a command's usage and exit 0  |

Option values: negative numbers pass plainly (`--par -5`); any other value that
begins with a dash needs the `=` form (`--notes="- first item"`).

## Read commands

| Command                | What it returns |
| ---------------------- | --------------- |
| `schema`               | Machine-readable catalog of every command, its params, and a `mutates` flag. The first thing a voice agent reads. |
| `tasks:today`          | Late/open/completed/missed counts and the actionable occurrences for today. `--date YYYY-MM-DD` for a past day, `--list <name>` to filter by list. |
| `tasks:history`        | Recent task completions. `--days N` (default 7), `--limit N` (default 100), `--include-undone`. |
| `inventory:gaps`       | Purchased products not covered by any order guide. `--limit N` (default 25). |
| `price:spikes`         | Recent purchases flagged as possible price spikes. `--limit N` (default 25). |
| `price:product`        | Price stats (latest/avg/low/high, totals, span) for one product, by name or `--id N`. |
| `products:search`      | Products matching a name or raw alias. `--limit N` (default 25). |
| `reviews:pending`      | Open normalization reviews awaiting a human decision. `--limit N` (default 50). |
| `purchasing:dashboard` | Top-line purchasing KPIs: spend, counts, category/supplier breakdown. |
| `staff:list`           | Users a completion can be attributed to (resolve "complete as Maria"). |
| `tasks:lists`          | Task lists with active task counts (resolve "add it to the closing list"). `--all` for archived. |
| `inventory:sections`   | Inventory sections with active item counts. |

## Mutating commands

These change state and are flagged `mutates: true` in `schema`. Both accept
`--dry-run` to preview the resolution first.

| Command             | What it does |
| ------------------- | ------------ |
| `tasks:create-list` | Creates a task list (key auto-derived from `--name`). Optional `--position`, `--notes`, `--display-start/--display-end`. |
| `tasks:create`      | Creates a task in a list. `--list <name\|id>` and `--title` required; `--recurrence one_time\|daily\|weekly\|monthly` (default daily) with the schedule it needs (`--due-time`, `--starts-on`, `--weekdays`, `--one-time-on`); optional `--instructions`, `--requires-photo`. Materializes the task's occurrences on save. |
| `inventory:add-item`| Adds an inventory item (key auto-derived from `--name`). `--section` is matched by name and created if new. Optional `--guide-frequency`, `--category`, `--count-unit`, `--pack-size`, `--par`, `--notes`. Units/pack sizes are never guessed — set only when passed. |
| `tasks:complete`    | Completes a task occurrence via `Tasks::CompleteOccurrence`. Target with `--occurrence <id>` or `--task <fuzzy title>`; attribution defaults to the logged-in user (`--user <email\|name\|id>` to override); optional `--notes`. Photo-required tasks are refused (no image to attach from a CLI). |
| `tasks:undo`        | Undoes today's completion of an occurrence (`Tasks::UndoCompletion`). Same targeting/attribution; optional `--note`. |

Run `bin/agent help <command>` for per-command options.

## Voice workflow

The intended loop for a transcribed voice request — e.g. *"mark sweep front of
house done, this is Maria"*:

0. **Authenticate.** `bin/agent login` once (or set `BAGEL_AGENT_TOKEN`); every
   domain command is gated until then.
1. **Learn the surface.** `bin/agent schema` once — the agent now knows every
   command, its params, which ones mutate, and which need auth.
2. **Read for context.** `bin/agent tasks:today` (and `staff:list` to resolve
   the speaker) so the agent acts on the right record at the right place.
3. **Resolve, don't guess.** Pass the spoken phrase as `--task "sweep front"`.
   Fuzzy targeting matches it against *today's actual occurrences*. If it's
   ambiguous the command fails with `type: "ambiguous"` and a `candidates`
   list — the agent asks the user which one rather than picking blindly.
4. **Confirm then commit.** `--dry-run` returns the resolved target so the
   agent can read it back ("I'll mark *Sweep front of house* done as Maria —
   ok?"); drop the flag to execute.

Every domain guard still applies because the commands call the same services
the UI does: already-completed, missed-window, photo-required, and the
same-operating-day undo rule are all enforced server-side, not in the CLI.

## Design notes

- **Reads are side-effect free; writes go through the real services.** Read
  commands let an agent reason freely. The two mutating commands
  (`tasks:complete`, `tasks:undo`) call the same `Tasks::*` services the
  controllers use, so domain guards can't be bypassed from the CLI. They are
  flagged `mutates: true` in `schema` and support `--dry-run`. (Note: even some
  reads run `OccurrenceBuilder` to materialize a day's occurrences, exactly as
  the dashboard does — an established read path, not a domain mutation.)
- **Reuse over reinvention.** Each command wraps an existing service or model
  scope (`Purchasing::InventoryGapAnalyzer`, `PriceObservation.spikes`,
  `Tasks::TaskMetrics`, …) so the CLI and the UI can't drift apart.
- **Where the code lives.** `bin/agent` boots Rails and calls `Agents::Cli`.
  The dispatcher, base `Command`, `Options` parser, `Authentication`, and
  `CredentialStore` sit under `app/services/agents/`; one class per command
  under `app/services/agents/commands/`. Add a command by creating the class and
  appending it to `Agents::Cli::REGISTRY` (it requires auth unless it calls
  `skip_auth!`).

## Not yet available

- **Recipes / menu items.** There is no recipe domain in the app yet (it's a
  "Future Direction" in `CONTEXT.md`). Recipe commands can't be added until that
  domain (models, costing via `PriceObservation`) is built.

## Adding a command

1. Subclass `Agents::Command`, declare `command`, `summary`, optional `usage`.
2. Implement `#call` returning a JSON-safe Hash/Array (no stdout writes).
3. Append the class to `Agents::Cli::REGISTRY`.
4. Add a case to `test/services/agents/cli_test.rb`.
