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
- `unit_quantity`
- `case_quantity`
- `quantity`
- `package_price`
- `case_pack_id`
- `inner_quantity`
- `inner_unit_price`
- `inner_unit_label`
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

`raw_quantity` and `raw_case_quantity` preserve the exact CSV text. `unit_quantity` and `case_quantity` store the parsed numeric values separately. `quantity` is the pricing quantity only when the line is clearly a unit purchase or a case purchase. If an approved `SupplierProductPack` fact says how many inner units are in a case, `inner_quantity` and `inner_unit_price` store the price per reviewed inner unit. If both unit and case quantities appear on the same row, the row is treated as mixed, package/comparable pricing is left blank, and the row is flagged for review because the line total cannot be safely split.

## SupplierProductPack

Stores reviewed facts about supplier case presentations. This table is intentionally separate from receipt imports because receipt CSV rows do not reliably state how many inner units are in a case.

Important fields:

- `supplier_id`
- `product_id`
- `raw_sku`
- `raw_name`
- `units_per_case`
- `inner_unit_label`
- `inner_package_size`
- `inner_unit_of_measure`
- `standard_unit`
- `source`
- `source_label`
- `source_snapshot_at`
- `approved`
- `confidence_score`
- `raw_data`

Only approved case-pack facts are used for automatic pricing. For example, if an approved fact says a cheese case contains four five-pound packs, the app can calculate price per case, price per pack, and price per pound from a case receipt line. Suggested or unapproved facts stay out of pricing calculations.

## PriceObservation

Critical historical price table. Each normal purchased item line creates one price observation.

Important fields:

- `product_id`
- `receipt_line_item_id`
- `observed_at`
- `package_price`
- `case_pack_id`
- `unit_quantity`
- `case_quantity`
- `purchase_kind`
- `inner_quantity`
- `inner_unit_price`
- `inner_unit_label`
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

This table powers product history, dashboards, price movement, and exports. `purchase_kind` is `unit`, `case`, `mixed`, or `unknown`. `presentation_key` keeps exact purchased forms separate for package-price charts, including whether the row was bought by unit or by case, while `standard_unit_price` lets the app compare different presentations when they share a reliable comparable unit.

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

Order-guide assignment belongs here, not on `Product`. A product is receipt/vendor/reporting-backed purchasing data. An inventory item is the operating item staff count, stock, and reorder. One inventory item can belong to multiple named order guides through `OrderGuideMembership`, with one active membership marked as the primary guide for simple screens.

`guide_frequency` is retained as compatibility metadata from the first guide import model. New workflows should read and write named guides through memberships.

## InventoryCount and InventoryCountLine

`InventoryCount` is one manual count event. `InventoryCountLine` stores one counted quantity for one inventory item.

These tables are intentionally simple first:

- blank count rows are skipped
- quantities are stored as entered
- no unit conversion is guessed
- guide-scoped counts should store the `order_guide_id` on the count and the `order_guide_membership_id` on each line
- new guide buy-list recommendations use membership-level expected usage plus buffer, not the legacy item-level par fields

## OrderGuideImport

Represents a legacy daily or weekly order guide PDF import.

Important fields:

- `source_filename`
- `source_path`
- `guide_type`
- `file_checksum`
- `raw_text`
- `rows_imported`
- `validation_summary`

The checksum prevents duplicate legacy PDF imports. New staff-facing guide workflows should use `OrderGuide` and `OrderGuideMembership`; future bulk setup should use the order-guide CSV shape exposed from the Order Guides page.

## OrderGuide

Represents a named reusable purchasing workflow such as `Daily`, `Weekly`, `Every 2 weeks`, `Monthly`, `Cleaning Supplies`, or `Weekend Prep`.

Important fields:

- `name`
- `key`
- `position`
- `active`
- `notes`

Guides are generic operating lists. They are intentionally separate from legacy imported files so staff can create useful working guides for any cadence or category. Archiving a guide sets it inactive instead of deleting it.

## OrderGuideSection

Represents a station/section inside one specific guide, such as `Dry storage`, `Front bar`, `Walk-in freezer`, or `Back fridge`.

Sections are guide-specific because the walking path can differ between a weekly guide, monthly guide, cleaning guide, and equipment guide.

## OrderGuideMembership

Joins one `InventoryItem` to one `OrderGuide`.

Important fields:

- `order_guide_id`
- `inventory_item_id`
- `order_guide_section_id`
- `preferred_supplier_id`
- `primary_guide`
- `active`
- `position`
- `tracking_mode`
- `expected_usage_quantity`
- `buffer_quantity`
- `par`
- `reorder_point`
- `notes`

Memberships are active/inactive so an item can be removed from a staff workflow without destroying traceability. `primary_guide` supports simple dropdown-driven workflows while preserving the many-guide design for future purchasing screens.

`tracking_mode` is either `counted` or `order_only`. Counted rows appear in guide counts and use `expected_usage_quantity + buffer_quantity` as the target after order. Order-only rows stay on the guide for manual purchasing but do not appear on count screens.

Legacy `par` and `reorder_point` values are preserved for traceability and older screens. New guide-specific buy lists should use expected usage plus buffer.

## OrderGuideItem

Stores one raw line from a legacy daily or weekly guide import.

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

Guide rows stay traceable to raw extracted text. `par_text` and `pack_quantity` are text fields because imported guide files are not structured enough to safely turn every row into a numeric par/unit.

Imported rows keep linking to `InventoryItem` through `inventory_item_id`. Legacy imports also create or reuse a named guide matching the import type, such as `Daily` or `Weekly`, and add a membership for the linked inventory item. That keeps raw import traceability in `OrderGuideItem` while making staff-facing ordering workflows use `OrderGuide` and `OrderGuideMembership`.

## Future Model Fit

The schema is ready for future menu costing models:

- `MenuItem`
- `Recipe`
- `MenuItemIngredient`
- `VendorProduct`

`InventoryItem` now exists as the bridge between operating guides and receipt-backed products. Future recipe/menu costing should use `Product` and `PriceObservation` as the price source of truth, and `InventoryItem` as the operating/counting surface.
