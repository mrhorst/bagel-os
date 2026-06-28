# Agent CLI (`bin/agent`)

A read-only, JSON-emitting command line that lets an agent (AI or human)
query Bagel OS domain data without scraping HTML. This is the first slice of
the "LLM assistant that answers through structured database queries, not raw
CSV/PDF scraping" direction in `CONTEXT.md`.

```sh
bin/agent help                       # list commands
bin/agent tasks:today                # pretty JSON
bin/agent price:product "house blend" --compact
```

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

Error `type` is one of `unknown_command`, `usage_error`, `not_found`,
`ambiguous`, `error`. An `ambiguous` error also carries a `candidates` array
(see "Voice workflow" below). This split (data on stdout, errors on stderr,
exit codes) lets a caller pipe stdout straight into a JSON parser and branch on
the exit status.

Money and decimal values serialize as **strings** so consumers never inherit
float rounding error on prices.

## Global options

| Option        | Effect                              |
| ------------- | ----------------------------------- |
| `--compact`   | Single-line JSON instead of pretty  |
| `--dry-run`   | On a mutating command, resolve and report what *would* happen without writing |
| `--help`, `-h`| Print a command's usage and exit 0  |

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
| `tasks:complete`    | Completes a task occurrence via `Tasks::CompleteOccurrence`. Target with `--occurrence <id>` or `--task <fuzzy title>`; attribute with `--user <email\|name\|id>` (required); optional `--notes`. Photo-required tasks are refused (no image to attach from a CLI). |
| `tasks:undo`        | Undoes today's completion of an occurrence (`Tasks::UndoCompletion`). Same targeting/attribution; optional `--note`. |

Run `bin/agent help <command>` for per-command options.

## Voice workflow

The intended loop for a transcribed voice request — e.g. *"mark sweep front of
house done, this is Maria"*:

1. **Learn the surface.** `bin/agent schema` once — the agent now knows every
   command, its params, and which ones mutate.
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
  The dispatcher, base `Command`, and `Options` parser sit under
  `app/services/agents/`; one class per command under
  `app/services/agents/commands/`. Add a command by creating the class and
  appending it to `Agents::Cli::REGISTRY`.

## Not yet available

- **Recipes / menu items.** There is no recipe domain in the app yet (it's a
  "Future Direction" in `CONTEXT.md`). Recipe commands can't be added until that
  domain (models, costing via `PriceObservation`) is built.

## Adding a command

1. Subclass `Agents::Command`, declare `command`, `summary`, optional `usage`.
2. Implement `#call` returning a JSON-safe Hash/Array (no stdout writes).
3. Append the class to `Agents::Cli::REGISTRY`.
4. Add a case to `test/services/agents/cli_test.rb`.
