# Bagel OS Agent Notes

This repository is the generic product source for restaurant inventory, order-guide, purchasing, and price intelligence work.

## Privacy Boundary

- Keep real restaurant names, receipt exports, order guide PDFs, vendor account data, staff/customer data, private notes, and agent prompts out of tracked files.
- Keep install-specific data inside the ignored `.private/` workspace.
- Generic tracked names like `Bagel OS`, `Demo Restaurant`, and `Primary Supplier` are intentional placeholders.
- If a deployment needs real branding, load it from `.private/branding.yml` instead of hard-coding it.
- Before committing, scan changed files for accidental private references.

## Engineering Defaults

- Prefer simple Rails, Active Record models, and server-rendered views.
- Preserve traceability back to raw receipt lines and raw order guide lines.
- Do not guess units, package sizes, or conversions. Leave uncertain values blank/text and flag them for review.
- Keep importer behavior idempotent wherever possible.
- Avoid adding frontend package managers or npm dependencies unless explicitly approved.

## Verification

Before committing meaningful changes, run:

```sh
bin/check-no-npm-surface
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Checkpoint Commits

- Create a focused git commit for every completed bug fix, refactor, feature, UI change, documentation update, or other meaningful repo change.
- Do not leave finished work as uncommitted changes unless explicitly told not to commit.
- Keep checkpoint commits small and scoped to the work just completed.
- Before committing, inspect `git status` and the staged diff so unrelated dirty files are not included.
- If the worktree already contains unrelated changes, leave them alone and stage only the files that belong to the current task.
- Use clear commit messages that describe the actual checkpoint, for example `Fix receipt line review flow` or `Improve product edit layout`.
- If verification cannot be run before a checkpoint commit, say so in the final response and explain why.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for the private `restaurant-inventory-os` repository. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context Rails app with root `CONTEXT.md` and ADRs in `docs/adr/`. See `docs/agents/domain.md`.

### Agent CLI

`bin/agent` gives agents JSON access to domain data (tasks, inventory gaps, prices, reviews), authoring actions (create lists/tasks/inventory items), and guarded task complete/undo for voice-driven flows. Authenticate first with `bin/agent login`; domain commands are gated on a session (the seam for future tenancy). Start with `bin/agent schema`. See `docs/agents/agent-cli.md`.

### Production observability & self-healing

A scheduled error-triage routine watches production (raw logs and/or a self-hosted GlitchTip) and turns real errors into fix PRs that `pr-watcher` merges. See `docs/deployment/observability.md` and `docs/agents/error-triage-routine.md`.
