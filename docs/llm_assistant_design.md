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

Configure the gateway with environment variables. For synchronous dashboard updates, prefer the OpenAI-compatible Hermes API endpoint:

- `TASK_BRIEFING_AGENT_GATEWAY_URL`: full HTTP endpoint for the local agent, for example `http://127.0.0.1:8642/v1/chat/completions`
- `TASK_BRIEFING_AGENT_GATEWAY_TOKEN`: optional secret. Chat completions use it as a bearer token. Webhook endpoints use it as an HMAC signing secret.
- `TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT`: optional timeout in seconds, default `8`; synchronous local LLM calls may need `60`

### Synchronous Chat Completions Endpoint

When `TASK_BRIEFING_AGENT_GATEWAY_URL` ends in `/v1/chat/completions`, the app sends an OpenAI-style request:

```json
{
  "model": "hermes-task-briefing",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "Return ONLY valid JSON. Generate a task briefing from this payload:\n\n{...Rails task payload...}"
    }
  ]
}
```

The request uses bearer auth when a token is present:

```txt
Authorization: Bearer <token>
```

The app expects the response content at `choices[0].message.content` to be JSON. It accepts either the canonical dashboard shape:

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

Or the Hermes summary/items shape:

```json
{
  "summary": "Opening task is overdue",
  "items": [
    {
      "title": "Check sanitizer buckets",
      "status": "late",
      "due": "8:00 AM",
      "note": "Use test strips before prep starts."
    }
  ]
}
```

### Async Webhook Endpoint

When a token is configured, the app signs the exact JSON request body with HMAC-SHA256 and sends both common webhook signature headers:

- `X-Hub-Signature-256: sha256=<hex digest>`
- `X-Webhook-Signature: <hex digest>`

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

If the gateway only returns an async acknowledgement such as `{"status":"accepted"}` and sends the actual briefing somewhere else, such as Telegram, the Rails dashboard will not receive the agent-written briefing. In that case, the dashboard safely falls back to the deterministic briefing. To show the agent-written text in Rails, use one of these patterns:

- **Synchronous response:** the webhook returns the briefing JSON in the HTTP response body.
- **Callback response:** the webhook accepts the event, then posts the briefing JSON back to a future Rails callback endpoint.

The app validates the response before displaying it:

- `headline` and `next_action` must be present.
- `priority_items` should reference task occurrence IDs from the request.
- If a priority item omits `task_occurrence_id`, the app tries a strict fallback match by exact task title plus optional list/status/due label.
- Unknown task IDs are ignored.
- The agent output is saved in `task_briefings`, not generated on every page render.
