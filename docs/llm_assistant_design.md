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

## Task Briefing Gateway

The Tasks dashboard can talk directly to a local agent gateway for shift briefings. If no gateway is configured, or the gateway returns an invalid response, the app falls back to its deterministic task-priority briefing.

Configure the gateway with environment variables:

- `TASK_BRIEFING_AGENT_GATEWAY_URL`: full HTTP endpoint for the local agent, for example `http://127.0.0.1:8787/gateways/task-briefing`
- `TASK_BRIEFING_AGENT_GATEWAY_TOKEN`: optional bearer token sent as `Authorization: Bearer ...`
- `TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT`: optional timeout in seconds, default `8`

The app sends a `POST` request with JSON:

```json
{
  "gateway": "task_briefing",
  "version": 1,
  "generated_at": "2026-06-02T09:05:00-04:00",
  "scope": {
    "type": "tasks_dashboard",
    "key": "today",
    "operating_date": "2026-06-02"
  },
  "instructions": [
    "Prioritize late work, due-soon work, food-safety-sensitive work, photo-evidence work, then monthly work.",
    "Do not invent tasks, legal requirements, completion claims, or compliance claims.",
    "Return JSON with headline, next_action, and up to three priority_items."
  ],
  "tasks": [
    {
      "task_occurrence_id": 123,
      "title": "Check sanitizer buckets",
      "instructions": "Use test strips before prep starts.",
      "list_name": "Opening",
      "status": "late",
      "due_at": "2026-06-02T08:00:00-04:00",
      "due_label": "8:00 AM",
      "requires_photo_evidence": false,
      "priority_bucket": 0
    }
  ]
}
```

The gateway should return JSON:

```json
{
  "headline": "Sanitizer check needs attention before prep gets busier.",
  "next_action": "Start with sanitizer buckets, then move into line restock.",
  "priority_items": [
    {
      "task_occurrence_id": 123,
      "reason": "It is already late and protects the food-safety workflow."
    }
  ]
}
```

The app validates the response before displaying it:

- `headline` and `next_action` must be present.
- `priority_items` must reference task occurrence IDs from the request.
- Unknown task IDs are ignored.
- The agent output is saved in `task_briefings`, not generated on every page render.
