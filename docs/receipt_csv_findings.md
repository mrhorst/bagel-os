# Receipt CSV Findings

This repository includes only sanitized receipt fixtures. Real vendor exports belong in `.private/receipts/`.

## Supported Shape

The current parser supports receipt CSVs with:

- a receipt/invoice line containing receipt number and timestamp
- an item header row with `UPC`, `Description`, `Unit Qty`, `Case Qty`, and `Price`
- item rows
- receipt total rows such as subtotal, tax, total, payment, and balance

## Reliably Parsed Fields

- receipt number
- purchase timestamp
- raw item name
- raw supplier item code / SKU
- unit quantity
- case quantity
- line price
- subtotal, tax, and total rows when present

## Conservative Fields

- package size and unit are parsed only when visible in the item description.
- unit quantity and case quantity are stored separately; they are not collapsed into one source value.
- standard unit prices are calculated only when package size, unit, purchase kind, quantity, and line price are reliable.
- case-pack rows are imported but standard unit price is left blank unless the case contents are explicit.
- approved case-pack facts can supply reviewed case contents, such as four packs per case, so the app can calculate price per inner unit and, when the inner size is known, price per comparable unit.
- rows with both unit and case quantities are imported for traceability, but per-unit/per-case pricing is left blank because the line total cannot be safely allocated.

## Data Quality Rules

- Duplicate files are skipped by checksum.
- Duplicate receipts are skipped by supplier and receipt number.
- Coupons and adjustments are imported for traceability but do not create product price observations.
- Ambiguous units, case packs, unknown categories, and uncertain product matches are flagged for review.

## Private Data Rule

Do not commit real receipt CSVs, customer numbers, store addresses, payment identifiers, exact purchase history, or vendor account details. Keep them under `.private/receipts/`.
