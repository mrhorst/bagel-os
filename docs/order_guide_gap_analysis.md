# Order Guide Gap Analysis

This app can compare imported order guide rows and named inventory guide memberships against receipt-backed products.

Real gap analysis output is private operating data and should be kept in `.private/notes/` or exported locally, not committed to this product repository.

## Refresh Workflow

1. Put current guide PDFs in `.private/order_guides/current/`.
2. Import and refresh matches:

```sh
bin/rails inventory:import_order_guides
bin/rails inventory:refresh_order_guide_matches
bin/rails inventory:guide_gaps
```

## Review Rules

- Count a product as covered when it is linked through an active `InventoryItem`, active imported guide row, or explicit conservative plain-language match.
- Use `OrderGuide` and `OrderGuideMembership` for staff-facing named guides. Keep `OrderGuideItem` as the traceable raw import row.
- Do not count broad guide wording as covering specific package/material differences.
- Classify missing products as review candidates, one-off/low-signal purchases, or occasional equipment/smallwares.
- Keep exact product spend, purchase frequency, and restaurant-specific decisions private unless intentionally published.
