# Data Model

## Supplier

Represents a vendor such as a wholesale supplier, grocery distributor, or retail store. `Primary Supplier` is seeded for local development.

Relationships:

- has many import batches
- has many receipts
- has many products
- has many price observations

## ImportBatch

Represents one import attempt for one CSV file.

Important fields:

- `source_filename`
- `source_path`
- `file_checksum`
- `status`
- `rows_processed`
- `rows_imported`
- `rows_failed`
- `validation_summary`

The checksum prevents duplicate file imports.

## Receipt

Represents one purchase receipt.

Important fields:

- `receipt_number`
- `purchased_at`
- `subtotal`
- `tax`
- `total`
- `raw_data`

Receipts are unique by supplier and receipt number.

## ReceiptLineItem

Represents one imported receipt line that should remain traceable to the raw CSV.

Important fields:

- `raw_name`
- `raw_sku`
- `raw_quantity`
- `raw_case_quantity`
- `quantity`
- `package_price`
- `line_total`
- `parsed_package_size`
- `parsed_unit_of_measure`
- `confidence_score`
- `needs_review`
- `raw_data`

Line types are `item`, `coupon`, or `adjustment`. Product price observations are created only for normal item rows.

## Product

Represents the canonical product used for reporting.

Important fields:

- `canonical_name`
- `supplier_sku`
- `product_category_id`
- `purchase_unit`
- `package_size`
- `unit_of_measure`
- `standard_unit`
- `notes`
- `active`
- `needs_review`

Products use simple canonical names for reporting when the receipt shorthand can be interpreted safely. For example, multiple tuna receipt names can roll up to `Tuna`.

When a product is a family with multiple raw SKUs or sizes, product-level SKU/package fields may be blank. The raw SKU, raw package text, parsed package size, and line-level price data remain on aliases, receipt line items, and price observations.

`notes` stores the conservative `Codex inference` explanation used to normalize raw supplier shorthand. Uncertain fallback names remain marked `needs_review`.

## ProductAlias

Maps raw receipt text to a canonical product.

Important fields:

- `raw_name`
- `raw_sku`
- `confidence_score`
- `approved`

Approved aliases are used for future exact matching and to show the receipt variations on product detail pages.

## ProductCategory

Human-readable reporting buckets, seeded with restaurant purchasing categories such as dairy, eggs, meat, produce, packaging, paper goods, cleaning supplies, and other/unknown.

## PriceObservation

Critical historical price table. Each normal purchased item line creates one price observation.

Important fields:

- `product_id`
- `receipt_line_item_id`
- `observed_at`
- `package_price`
- `quantity`
- `line_total`
- `unit_price`
- `standard_unit_price`
- `standard_unit`
- `standard_quantity`
- `presentation_key`
- `presentation_label`
- `source_filename`
- `possible_price_spike`

This table powers product history, dashboards, price movement, and exports. `presentation_key` keeps exact purchased forms separate for package-price charts, while `standard_unit_price` lets the app compare different presentations when they share a reliable comparable unit.

## NormalizationReview

Tracks uncertain parsing, categorization, and merge decisions.

Important fields:

- `receipt_line_item_id`
- `product_id`
- `issue_type`
- `description`
- `status`
- `resolution_notes`

Statuses are `pending`, `resolved`, and `ignored`.

## InventorySection

Represents a section from the operating guide, such as `Dairy & Refrigerated`, `Paper Packaging`, or `Fresh Produce`.

Relationships:

- has many inventory items
- has many inventory counts

## InventoryItem

Represents the working inventory/order-guide item staff count and order against.

Important fields:

- `name`
- `key`
- `inventory_section_id`
- `product_id`
- `preferred_supplier_id`
- `category`
- `subcategory`
- `count_unit`
- `pack_size`
- `current_par`
- `reorder_point`
- `guide_frequency`
- `needs_review`
- `raw_data`

`product_id` is optional because many guide rows do not confidently match a receipt product yet. The app only links an inventory item to a product when the name match is exact or covered by an explicit conservative rule.

## InventoryCount and InventoryCountLine

`InventoryCount` is one manual count event. `InventoryCountLine` stores one counted quantity for one inventory item.

These tables are intentionally simple first:

- blank count rows are skipped
- quantities are stored as entered
- no unit conversion is guessed
- buy-list recommendations only work when an inventory item has a par level and a latest count

## OrderGuideImport

Represents one daily or weekly order guide PDF import.

Important fields:

- `source_filename`
- `source_path`
- `guide_type`
- `file_checksum`
- `raw_text`
- `rows_imported`
- `validation_summary`

The checksum prevents duplicate PDF imports. Older PDF files are preserved on disk in `.private/order_guides/archive/`.

## OrderGuideItem

Stores one raw line from the daily or weekly guide.

Important fields:

- `guide_type`
- `section_name`
- `subcategory`
- `item_name`
- `guide_sku`
- `par_text`
- `pack_quantity`
- `raw_line`
- `inventory_item_id`
- `match_confidence`
- `needs_review`
- `raw_data`

Guide rows stay traceable to raw extracted PDF text. `par_text` and `pack_quantity` are text fields because the PDFs are not structured enough to safely turn every row into a numeric par/unit.

## Future Model Fit

The schema is ready for future menu costing models:

- `MenuItem`
- `Recipe`
- `MenuItemIngredient`
- `VendorProduct`

`InventoryItem` now exists as the bridge between operating guides and receipt-backed products. Future recipe/menu costing should use `Product` and `PriceObservation` as the price source of truth, and `InventoryItem` as the operating/counting surface.
