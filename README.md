# Bagel OS

Rails app for restaurant inventory, order guides, vendor receipt imports, purchasing analytics, and price intelligence.

This repository is designed to stay reusable and safe to share. Real restaurant names, branding, receipt exports, vendor PDFs, private notes, and install-specific data belong in the ignored `.private/` workspace or in a separate private data repository.

## What It Does

- Imports vendor receipt CSV exports into receipts, line items, products, aliases, and price observations.
- Normalizes supplier shorthand conservatively while keeping raw receipt rows traceable.
- Imports daily/weekly order guide PDFs from private local folders.
- Builds an inventory item list from order guides and links items to receipt-backed products when the match is explicit.
- Shows dashboards for spend, recurring products, price movement, order-guide gaps, and review queues.
- Supports manual inventory counts and par-based shopping-list recommendations.
- Exports CSV reports for products, purchases, price history, category spend, frequent items, spikes, and review items.

## Setup

```sh
bundle install
bin/rails db:setup
```

The default local database is SQLite. No production secrets are committed.

## Private Workspace

Create install-specific files under `.private/`:

```text
.private/
  branding.yml
  receipts/
  order_guides/
    current/
  seed_data/
  notes/
  agents/
```

Example branding file:

```yaml
# .private/branding.yml
app_name: "Your Restaurant Bagel OS"
short_name: "Bagel OS"
description: "Inventory, purchasing, and order-guide intelligence for your restaurant."
```

The `.private/` folder is ignored by git. It can be initialized as its own private repository if a specific restaurant needs versioned operating data.

## Import Receipts

By default, receipt imports read from `.private/receipts/`:

```sh
bin/rails purchasing:import_all
```

To import from another folder:

```sh
SOURCE_DIR=/path/to/csvs bin/rails purchasing:import_all
```

The importer is idempotent by file checksum and receipt number.

## Import Order Guides

Place current daily/weekly order guide PDFs under `.private/order_guides/current/`, then run:

```sh
bin/rails inventory:import_order_guides
bin/rails inventory:refresh_order_guide_matches
bin/rails inventory:guide_gaps
```

The PDF importer uses `pdftotext -layout`. It keeps raw guide text and does not guess units from ambiguous PDF spacing.

## App Pages

- `/` purchasing dashboard
- `/inventory` inventory and guide dashboard
- `/inventory/items` master inventory list
- `/inventory/counts/new` manual count sheet
- `/inventory/shopping-list` par-based buy list
- `/order_guides` guide rows and receipt-product gaps
- `/products` master product list
- `/normalization_reviews` human review queue
- `/reports` CSV exports

## Useful Tasks

```sh
bin/rails purchasing:import_all
bin/rails purchasing:export_reports
bin/rails purchasing:import_case_pack_facts
bin/rails purchasing:recalculate_price_observations
bin/rails purchasing:renormalize_products
bin/rails purchasing:flag_reviews
bin/rails inventory:import_order_guides
bin/rails inventory:refresh_order_guide_matches
bin/rails inventory:guide_gaps
```

Case-pack facts are reviewed supplier presentation facts, such as a case containing four inner packs. By default the importer reads `.private/case_pack_facts.csv`, or pass `CASE_PACK_FACTS=/path/to/file.csv`. Keep these files private when they contain real vendor/product data.

## Quality Checks

```sh
bin/check-no-npm-surface
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Supply Chain Guardrail

This app is intentionally npm-free. `bin/check-no-npm-surface` fails if JavaScript package manifests, lockfiles, `node_modules`, npm config files, or npm/yarn/pnpm/bun commands are introduced. See `docs/supply_chain_guardrails.md`.

## Known Limitations

- Receipt CSV support is based on the current wholesale supplier export shape and should be extracted into adapter classes as more vendors are added.
- Order-guide PDF parsing is conservative and keeps ambiguous values as text.
- Manual inventory counts work, but count editing and in-app product-link approval screens are still future work.
- No authentication has been added yet; treat this as an internal tool until auth is implemented.
- No LLM assistant is implemented yet. See `docs/llm_assistant_design.md`.
