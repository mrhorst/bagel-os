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

Error `type` is one of `unknown_command`, `usage_error`, `not_found`, `error`.
This split (data on stdout, errors on stderr, exit codes) lets a caller pipe
stdout straight into a JSON parser and branch on the exit status.

Money and decimal values serialize as **strings** so consumers never inherit
float rounding error on prices.

## Global options

| Option        | Effect                              |
| ------------- | ----------------------------------- |
| `--compact`   | Single-line JSON instead of pretty  |
| `--help`, `-h`| Print a command's usage and exit 0  |

## Commands

| Command                | What it returns |
| ---------------------- | --------------- |
| `tasks:today`          | Late/open/completed/missed counts and the actionable occurrences for today. `--date YYYY-MM-DD` for a past day, `--list <name>` to filter by list. |
| `tasks:history`        | Recent task completions. `--days N` (default 7), `--limit N` (default 100), `--include-undone`. |
| `inventory:gaps`       | Purchased products not covered by any order guide. `--limit N` (default 25). |
| `price:spikes`         | Recent purchases flagged as possible price spikes. `--limit N` (default 25). |
| `price:product`        | Price stats (latest/avg/low/high, totals, span) for one product, by name or `--id N`. |
| `products:search`      | Products matching a name or raw alias. `--limit N` (default 25). |
| `reviews:pending`      | Open normalization reviews awaiting a human decision. `--limit N` (default 50). |
| `purchasing:dashboard` | Top-line purchasing KPIs: spend, counts, category/supplier breakdown. |

Run `bin/agent help <command>` for per-command options.

## Design notes

- **Read-only by design.** Commands are side-effect free so an agent can call
  them freely while reasoning. `tasks:today` is the one exception worth knowing:
  it runs `OccurrenceBuilder` to materialize the day's occurrences, exactly as
  the Tasks dashboard does — that is the established read path, not a mutation of
  domain decisions.
- **Reuse over reinvention.** Each command wraps an existing service or model
  scope (`Purchasing::InventoryGapAnalyzer`, `PriceObservation.spikes`,
  `Tasks::TaskMetrics`, …) so the CLI and the UI can't drift apart.
- **Where the code lives.** `bin/agent` boots Rails and calls `Agents::Cli`.
  The dispatcher, base `Command`, and `Options` parser sit under
  `app/services/agents/`; one class per command under
  `app/services/agents/commands/`. Add a command by creating the class and
  appending it to `Agents::Cli::REGISTRY`.

## Adding a command

1. Subclass `Agents::Command`, declare `command`, `summary`, optional `usage`.
2. Implement `#call` returning a JSON-safe Hash/Array (no stdout writes).
3. Append the class to `Agents::Cli::REGISTRY`.
4. Add a case to `test/services/agents/cli_test.rb`.
