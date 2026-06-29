module Agents
  module Commands
    # The price profile for one product: latest/average/low/high, totals, and
    # purchase span. The pricing answer behind "what do we pay for X?".
    class PriceProduct < Command
      command "price:product"
      summary "Price stats for one product (by name or --id)"
      usage(
        "Usage: bin/agent price:product <name> [--id N]",
        "",
        "Options:",
        "  --id N   Resolve by product id instead of a name query"
      )
      param :name, positional: true, desc: "Product name query (or use --id)"
      param :id, type: "integer", desc: "Resolve by product id instead of a name query"

      def call
        product = ProductLookup.resolve(id: options.value("id"), query: options.positional(0))
        stats = product.price_stats

        {
          product: {
            id: product.id,
            canonical_name: product.canonical_name,
            supplier: product.supplier&.name,
            category: product.category_name,
            standard_unit: product.standard_unit
          },
          stats: stats_json(stats)
        }
      end

      private

      # price_stats mixes money decimals, plain counts, and timestamps — money
      # goes through #money, counts pass through, timestamps to ISO 8601.
      def stats_json(stats)
        {
          latest_price: money(stats[:latest_price]),
          average_price: money(stats[:average_price]),
          lowest_price: money(stats[:lowest_price]),
          highest_price: money(stats[:highest_price]),
          latest_standard_unit_price: money(stats[:latest_standard_unit_price]),
          average_standard_unit_price: money(stats[:average_standard_unit_price]),
          total_times_purchased: stats[:total_times_purchased],
          total_spend: money(stats[:total_spend]),
          first_purchase_date: iso(stats[:first_purchase_date]),
          last_purchase_date: iso(stats[:last_purchase_date])
        }
      end
    end
  end
end
