# Agent CLI (`bin/bagel`)

`bin/bagel` is the agent-facing command line for the operational modules:
tasks, follow-ups, and the log book. It boots the Rails environment and
goes through the same models and services as the web UI, so validations,
snapshots, occurrence building, and follow-up syncing behave identically.

```sh
bin/bagel <resource> <action> [options]
bin/bagel --help                 # resources
bin/bagel tasks --help           # actions + options per resource
```

## Output contract

Every action prints a JSON envelope on stdout and uses the exit code:

```json
{"ok": true,  "data": { ... }}                          // exit 0
{"ok": false, "error": "...", "details": ["..."]}       // exit 1
```

`details` carries Active Record validation messages when a write fails
validation. Help output is plain text. Boot noise (gem warnings) goes to
stderr, so pipe stdout straight into a JSON parser.

## Attribution

Write actions accept `--user EMAIL` to attribute the change to an existing
user (opened_by / resolved_by / note author / log book submitter). Without
it the write is unattributed, which the models allow. There is no staff
auth at the CLI boundary — same as the web UI's staff-attribution model.

## Resources

### tasks

```sh
bin/bagel tasks list [--all | --archived] [--list LIST]
bin/bagel tasks show ID
bin/bagel tasks create --title TITLE --list LIST [schedule options]
bin/bagel tasks update ID [options]
bin/bagel tasks archive ID
bin/bagel tasks reactivate ID
```

`LIST` is a task list ID or key. Schedule shape is validated by the model
per `--recurrence` (one_time | daily | weekly | monthly — default daily):
one_time needs `--one-time-on` + `--due-time`; daily/weekly need
`--starts-on` (defaults to today on create) + `--due-time`; weekly also
needs `--weekdays` (0-6 or names, e.g. `mon,thu`); monthly needs
`--starts-on`. Successful writes refresh open occurrences and broadcast,
exactly like the manage UI.

```sh
bin/bagel tasks create --title "Wipe down slicer" --list opening --due-time 16:00
bin/bagel tasks create --title "Clean hood filters" --list closing \
  --recurrence weekly --weekdays mon,thu --due-time 21:00
```

### task-lists

```sh
bin/bagel task-lists list [--all]
bin/bagel task-lists create --name NAME [--notes TEXT] [--position N]
```

The key is derived from the name; position is auto-assigned when omitted.

### follow-ups

```sh
bin/bagel follow-ups list [--status open|resolved|all] [--limit N]
bin/bagel follow-ups show ID
bin/bagel follow-ups create --title TITLE [--description TEXT] [--urgency LEVEL] [--assign EMAIL] [--user EMAIL]
bin/bagel follow-ups update ID [--title ...] [--description ...] [--urgency ...] [--assign EMAIL | --unassign]
bin/bagel follow-ups resolve ID [--via KIND] [--note TEXT] [--user EMAIL]
bin/bagel follow-ups reopen ID [--user EMAIL]
bin/bagel follow-ups note ID --body TEXT [--user EMAIL]
```

Urgency: `normal | important | urgent`. Resolution kinds:
`action_taken | converted_to_task | duplicate | not_an_issue`
(default `action_taken`).

### log-book

```sh
bin/bagel log-book sections                  # section IDs, types, multi fields
bin/bagel log-book show [--date YYYY-MM-DD]  # read any date
bin/bagel log-book set --section SECTION [value options]   # writes TODAY only
```

`SECTION` is a section ID or exact title. `set` has partial-update
semantics: it only changes what you pass; existing values, flags, and
urgency are preserved. Value flags must match the section type
(`--text`, `--number`, `--answer yes|no`, repeatable `--grid KEY=VALUE`,
or `--no-note`). Flagging follows the log book rules: `--flag` opens a
follow-up, `--unflag` resolves it — both via `LogBook::SyncResponses` →
`FollowUps::SyncFromLogBookResponse`, so history matches a web save.

```sh
bin/bagel log-book set --section "Shift notes" --text "Slow morning, big lunch rush"
bin/bagel log-book set --section "Fridge temp" --number 38
bin/bagel log-book set --section "Shift notes" --flag --urgency urgent
```

Past entries are read-only, same rule as the web UI.

## Where the code lives

- Entry point: `bin/bagel` → `AgentCli::Runner` (`lib/agent_cli/`)
- One command class per resource; shared parsing in `AgentCli::BaseCommand`
- Output shapes: `AgentCli::Serializers`
- Log book writes share `LogBook::SyncResponses` with `LogBookController`
- Tests: `test/cli/`
