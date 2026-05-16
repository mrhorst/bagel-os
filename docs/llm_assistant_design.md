# Future LLM Assistant Design

## Source of Truth

The database should be the source of truth, not raw CSV files.

Raw CSVs are messy import inputs. The LLM should answer questions from structured tables:

- suppliers
- receipts
- receipt line items
- products
- product aliases
- product categories
- price observations
- normalization reviews

This keeps answers traceable, testable, and safer for business decisions.

## Allowed Tool / Query Types

The assistant should be allowed to run read-only query tools such as:

- product lookup by name, SKU, category, or supplier
- spend by date range
- spend by category
- price history for a product
- products with largest price increase or decrease
- recurring purchases by frequency
- items needing review
- products missing standard unit price
- last purchased date by product/category
- export/report generation

For future menu costing, it can use structured recipe/menu tables after those exist.

## What The LLM Should Not Do

The LLM should not:

- read raw CSVs directly as its primary source of truth
- invent missing package sizes or unit conversions
- auto-merge products without an approved rule
- write live supplier/POS/accounting data without approval
- hide uncertainty in calculations
- answer food-cost questions from unreviewed products without warning

## Response Requirements

For operational questions, the assistant should show:

- answer
- date range
- filters used
- whether reviewed-only data was used
- rows/products excluded because they need review
- link or reference to the source report/product/receipt where possible

## Example Future Questions

- What did eggs cost us last month?
- Which items went up the most?
- Show me our top 20 recurring purchases.
- What should I review before placing my next supplier order?
- Which products need better unit normalization?
- Estimate the cost of a nova sandwich based on current ingredient prices.
- What are our biggest paper goods expenses?
- What items do we buy every week?
- Which products have not been purchased recently?

## Recommended Implementation

Start with read-only service objects that return structured hashes, then expose those to an LLM tool layer.

Recommended first tools:

- `find_products(query:, category:, needs_review:)`
- `product_price_history(product_id:, mode:, start_date:, end_date:)`
- `category_spend(start_date:, end_date:)`
- `frequent_items(start_date:, end_date:, limit:)`
- `items_needing_review(limit:)`
- `price_spike_alerts(start_date:, end_date:)`

All LLM-facing tools should be logged and should return IDs so the UI can link back to database records.
