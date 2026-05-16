# Normalization Rules

## Core Principle

Do not guess. If the importer cannot confidently calculate or merge something, it leaves the field blank and creates a review flag.

## Product Matching

Allowed automatic matches:

- Same normalized supplier product family from the receipt shorthand interpreter.
- Same approved product alias with exact raw name and SKU.
- Same supplier and exact SKU/item code only when the item is not part of a broader normalized family.
- Same order-guide item and receipt product when the wording is exact or covered by a specific plain-language rule.

Not allowed automatically:

- Similar names with different SKUs.
- Similar names with no supported interpreter rule.
- Different brands or flavors unless a specific rule says they are one purchasing family.
- Different operational variants, formats, or colors when those affect purchasing or prep. For example, `American Cheese Yellow` stays separate from `American Cheese White`, and `Sausage Patties` stays separate from `Sausage Links`.
- Unit or package conversions that are not visible in the receipt row.

Possible name matches are flagged as `possible_alias_match`.

## Order Guide Matching

Order guide PDFs are treated as operating documents, not as proof of package size or unit conversion.

Allowed guide-to-product links:

- exact canonical product names
- exact raw receipt aliases
- explicit plain-language rules such as `Oatmilk` to `Oat Milk`, `Fries` to `Crinkle Cut Fries`, `Use-First Labels` to `Shelf Life Labels`, and `Lids 2oz` to `Portion Cup Lids`
- section-aware rules where context matters, such as daily `Rye` under `Sliced Bread` to `Rye Bread`

Not allowed automatically:

- broad container names to specific materials or sizes, such as `Large Containers (Takeout)` to `Foam Hinged Containers`
- cup names when material is unclear, such as `Cups (Takeout) 16oz` to `Foam Cups`
- different glove materials, such as latex to nitrile
- any unit conversion inferred from PDF spacing

Unlinked guide rows are marked `needs_review`. Receipt products that are not covered by active guide rows show up in the order-guide gap analysis.

## Simple Product Names

Supplier receipt names are often register shorthand. The importer uses `Purchasing::ProductNameInterpreter` to create simple master products while preserving raw receipt names as aliases.

Examples:

- `TUNA CHUNK LT CQ 66Z` and `TUNA TONGOL CQ 66Z` become `Tuna`.
- `EGGS LRG LS GRD A 15DZ` and `EGGS XLG LS GRD A 15DZ` become `Eggs`.
- `CHS CREAM BULK JF 30LB` and `CHS CRM JF SOFT 5LB` become `Cream Cheese`.

The raw names and SKUs are still shown on the product detail page as receipt variations. For grouped products, product-level SKU/package fields can be blank or show `varies`; the receipt lines and price observations remain the source of truth for package and unit details.

The interpreter writes a conservative `Codex inference` note into `Product.notes`. That note records the basis for the simple name, raw variations seen, confidence, and a reminder that missing unit conversions were not invented.

## Product Creation

When no exact match exists, the importer creates a new product using:

- interpreted simple canonical name when supported
- supplier SKU when present
- category from conservative keyword matching
- parsed package size/unit when reliable
- `needs_review = true` when category or name interpretation is uncertain

Grouped product families keep SKUs in `ProductAlias` rather than forcing one product-level SKU.

## Unit Parsing

The parser accepts clear tokens such as:

- `LB`, `LBS`, `#` when the number comes before the symbol, such as `15#`
- `OZ` or `Z`, such as `20Z`
- `GAL`
- `QT`, `QRT`, `QUART`
- `PT`, `PINT`
- `L`, `LTR`, `LITER`
- `DZ`
- `CT`
- `ROLL`
- `SHEET`

The parser does not standardize ambiguous multi-pack patterns such as:

- `6-20OZ`
- `2/8.3Z`
- `2.5MCT`

Those rows are flagged for review.

## Case Quantity

If `Case Qty` is greater than zero and the receipt text clearly exposes what appears to be the full purchased presentation, the importer calculates comparable unit price from:

`line total / (case quantity * package size)`

Example: two `25LB` cases for `$45.00` becomes `50 lb` at `$0.90/lb`.

If `Case Qty` is greater than zero and the visible package size may be an inner pack rather than the full case, standard unit price is left blank and the row is flagged for review. For example, a case row that says `1LB` or `32Z` may represent a case of many one-pound or quart packages, so the app will not pretend that the whole case was only one pound or one quart.

## Random Weight / Decimal Quantity

Rows with decimal quantity or `R/W` are imported and package/raw unit price is calculated as line total divided by quantity.

Standard unit price remains blank unless the unit is explicit. These rows are flagged for review.

## Price Calculation

Stored values:

- `line_total`: the CSV `Price` value.
- `quantity`: `Unit Qty` when positive, otherwise `Case Qty` when positive.
- `package_price`: `line_total / quantity` when quantity is positive. This is the price for that exact purchased presentation.
- `standard_quantity`: `quantity * package_size` when package size/unit is explicit.
- `standard_unit_price`: `line_total / standard_quantity` when package size/unit is explicit, quantity is positive, and line total is positive.
- `presentation_key`: exact purchased form used to keep package-price chart lines separate.

Coupons are imported for traceability but do not create product price observations.

## Price Charts

Product price history defaults to comparable unit price when reliable standard unit prices exist.

Package/presentation price charts do not connect different purchased forms. For example, a `25 lb` banana case and a `1 lb` banana purchase appear as separate presentation series. The comparable unit chart may compare them if both rows confidently calculate to the same standard unit, such as dollars per pound.

## Review Flags

Rows can be flagged for:

- `coupon`
- `unit_parse`
- `case_pack`
- `missing_category`
- `possible_alias_match`

The review queue lets a human assign a row to an existing product, create a new product, resolve, or ignore the review.

Product name inference can be auto-reviewed when an explicit interpreter rule fires and the category is known. Unit and case-pack issues remain reviewable separately.
