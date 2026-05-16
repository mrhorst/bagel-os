# Inventory OS Context

Inventory OS is a Rails application for restaurant operators who need one place to connect inventory counts, order guides, receipt imports, purchasing history, and price intelligence.

## Product Domain

The app models:

- suppliers and vendor receipt imports
- receipts and receipt line items
- normalized products and raw product aliases
- price observations for historical price tracking
- order guide imports and guide rows
- inventory items and inventory counts
- review queues for uncertain parsing, matching, and unit normalization

## Core Principles

- Correct numbers matter more than flashy UI.
- Every imported value should be traceable to the raw receipt line or order guide line it came from.
- Do not guess units, package sizes, conversions, or product merges.
- Keep real restaurant data in `.private/` or a separate private data repo.
- Keep tracked code and docs generic enough to reuse across restaurants.

## Current Architecture

- Rails with Active Record and server-rendered views.
- SQLite for local development by default.
- No npm package surface.
- Vendor receipt parsing, order-guide parsing, matching, pricing, and reporting live under `app/services/purchasing/`.

## Future Direction

- Supplier-specific importer adapters.
- In-app approval screens for guide/product links.
- Recipe and menu item costing using `PriceObservation` as the pricing source of truth.
- Optional LLM assistant that answers through structured database queries, not raw CSV/PDF scraping.
