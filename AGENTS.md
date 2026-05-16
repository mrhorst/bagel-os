# Inventory OS Agent Notes

This repository is the generic product source for restaurant inventory, order-guide, purchasing, and price intelligence work.

## Privacy Boundary

- Keep real restaurant names, receipt exports, order guide PDFs, vendor account data, staff/customer data, private notes, and agent prompts out of tracked files.
- Keep install-specific data inside the ignored `.private/` workspace.
- Generic tracked names like `Inventory OS`, `Demo Restaurant`, and `Primary Supplier` are intentional placeholders.
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

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for the private `restaurant-inventory-os` repository. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context Rails app with root `CONTEXT.md` and ADRs in `docs/adr/`. See `docs/agents/domain.md`.
