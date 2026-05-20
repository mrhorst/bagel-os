# Operating in this project

Read this first. It's the short version — the longer one is in [`AGENTS.md`](AGENTS.md) and [`CONTEXT.md`](CONTEXT.md).

## What this repo is

This is the **generic, public source** for Inventory OS — restaurant inventory, purchasing, order guides, and price intelligence. It is **not** a single tenant's installation. Anything tracked here must make sense for every deployment, not for one specific restaurant.

## Privacy boundary (the rule that breaks the most often)

**Nothing branded, identifiable, or operational from a real restaurant goes into tracked files.** That includes:

- Real restaurant / business names (e.g. "Bagel Time")
- Real vendor names, account numbers, SKUs, receipt exports, PDFs
- Staff names, customer data, private notes
- Brand colors, logos, fonts that belong to a specific tenant
- Screenshots taken against a live dev database loaded with real data
- Production credentials of any kind

**Where private data lives:**
- `.private/` — gitignored. Per-install branding, vendor exports, local notes, design artifacts captured from a branded dev environment, agent prompts. Nothing here is ever committed.
- `.private/branding.yml` — runtime branding overrides; loaded by `AppBranding` if present.
- `data/receipts/`, `data/order_guides/` — both gitignored. Keep real exports out of the tree.

**Generic placeholders that ARE tracked:**
- `Inventory OS`, `Demo Restaurant`, `Primary Supplier` — intentional defaults. Don't replace them with real names.

**Before every commit**, scan the staged diff for:
- Real proper nouns (restaurant / vendor / staff names)
- Hard-coded brand colors or hex values for a tenant
- Screenshots, PDFs, CSVs that came from a live dev environment
- Anything mentioned in `.private/`

If something private slipped through, **stop and move it to `.private/`** before pushing.

## Engineering defaults

- Server-rendered Rails + Hotwire/Stimulus. No SPA, no React, no npm.
- Active Record models; preserve traceability from a derived field back to the raw receipt or order-guide line that produced it.
- Don't guess units, package sizes, or unit conversions. Leave uncertain values blank or text and create a normalization review.
- Imports must be idempotent — re-running the same source should not duplicate rows.
- Tailwind CSS v4 via `tailwindcss-rails`. The design system lives in `app/assets/tailwind/application.css` (tokens at top, components below). When restyling, prefer editing tokens or component classes over sprinkling utility classes — the existing class names are stable.

## Design system

Tokens, components, and applied screens are documented in the Claude Design bundle at `.private/design-handoff/` (if present locally). Visual rules to follow:

- **One radius** (`--radius-md` = 10 px). Pills only for tags and the bottom-tab badges.
- **Two elevation levels** (`--shadow-e1`, `--shadow-e2`). No deeper shadows.
- **Accent (orange) = ONE meaning**: primary action / brand affirmative. Never use it for warnings or errors.
- **Status row indication = 2 px left rule**, never a painted row background. (See `.task-row-late`, `.warning-row`, `.dashboard-block-urgent`, `.decision-card`.)
- **Tabular numerals** on every data surface — KPI tiles, prices, tables, etc.
- **Mobile** (<640px): sidebar collapses to a slim brand bar; bottom tab nav is the primary nav.

## Verification before committing

Run before every meaningful change:

```sh
bin/check-no-npm-surface
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

If you can't run them (e.g. mid-design pass), say so in your final message and explain why.

## Commits

- One focused commit per completed unit of work — bug fix, refactor, feature, UI change, doc update. Don't batch.
- Imperative-mood subject, short. Recent style: `Polish tasks flow`, `Apply Inventory OS design system v1`, `Fix task due times timezone`.
- Use HEREDOC for multi-line bodies to keep formatting clean.
- Inspect `git status` and `git diff --staged` before committing — leave unrelated dirty files alone.
- Never amend or force-push without an explicit instruction; the standard move is a new commit.

## Common operations

```sh
bin/dev                          # Foreman: rails server + tailwind:watch
bin/rails tailwindcss:build      # One-off CSS build (faster than restarting bin/dev)
bin/rails test                   # Full test suite
bin/rails runner "puts X.count"  # Quick db poke
```

## More

- Domain context, models, and importer behavior: [`CONTEXT.md`](CONTEXT.md)
- Agent skills (issue tracker, triage labels, domain notes): `docs/agents/`
- ADRs: `docs/adr/`
