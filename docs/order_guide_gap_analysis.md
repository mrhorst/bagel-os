# Order Guide Gap Analysis

This app compares named inventory guide memberships against receipt-backed products.

Real gap analysis output is private operating data and should be kept in `.private/notes/` or exported locally, not committed to this product repository.

## Refresh Workflow

1. Create named guides in the app, such as `Daily`, `Weekly`, `Every 2 weeks`, or `Cleaning Supplies`.
2. Assign inventory items to the right primary guide from Master Inventory.
3. Run the gap report when you need a receipt-backed cross-check:

```sh
bin/rails inventory:guide_gaps
```

The app also provides a downloadable order-guide CSV example from the Order Guides page. That CSV shape is the preferred future import path for bulk guide setup.

## Review Rules

- Count a product as covered when it is linked through an active `InventoryItem` or explicit conservative plain-language match.
- Use `OrderGuide` and `OrderGuideMembership` for staff-facing named guides. Keep legacy `OrderGuideItem` rows as traceable raw import history where they exist.
- Do not count broad guide wording as covering specific package/material differences.
- Classify missing products as review candidates, one-off/low-signal purchases, or occasional equipment/smallwares.
- Keep exact product spend, purchase frequency, and restaurant-specific decisions private unless intentionally published.
