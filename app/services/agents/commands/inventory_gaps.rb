module Agents
  module Commands
    # Products that have purchase history but are missing from every order
    # guide — the buying coverage gaps. Wraps Purchasing::InventoryGapAnalyzer.
    class InventoryGaps < Command
      command "inventory:gaps"
      summary "Purchased products not covered by any order guide"
      usage(
        "Options:",
        "  --limit N   Cap the number of gap rows returned (default 25)"
      )
      param :limit, type: "integer", desc: "Cap the number of gap rows returned (default 25)"

      def call
        limit = options.integer("limit", 25)
        analyzer = Purchasing::InventoryGapAnalyzer.new

        # One scan: fetch the full row set, derive the summary from it, and
        # slice the limit locally (the analyzer walks every purchased product,
        # so running it twice doubled the command's cost).
        all_rows = analyzer.missing_products
        summary = analyzer.summary(rows: all_rows)
        rows = all_rows.first(limit)

        {
          summary: summary,
          rows: rows.map { |row| row_json(row) }
        }.merge(page_meta(returned: rows.size, limit: limit, truncated: all_rows.size > rows.size))
      end

      private

      def row_json(row)
        {
          product_id: row.product.id,
          product: row.product.canonical_name,
          classification: row.classification,
          reason: row.reason,
          purchase_count: row.purchase_count,
          total_spend: money(row.total_spend),
          last_purchased_at: iso(row.last_purchased_at)
        }
      end
    end
  end
end
