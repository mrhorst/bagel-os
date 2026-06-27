module Agents
  module Commands
    # Find products by canonical name or raw alias — the lookup an agent runs
    # before asking for a price profile.
    class ProductsSearch < Command
      command "products:search"
      summary "Search products by name or raw alias"
      usage(
        "Usage: bin/agent products:search <query> [--limit N]",
        "",
        "Options:",
        "  --limit N   Cap the number of products returned (default 25)"
      )
      param :query, positional: true, required: true, desc: "Name or raw alias to search for"
      param :limit, type: "integer", desc: "Cap the number of products returned (default 25)"

      def call
        query = options.positional(0)
        raise UsageError, "Provide a search query" if query.blank?

        limit = options.integer("limit", 25)
        products = ProductLookup.search(query, limit: limit).includes(:supplier, :product_category)

        {
          query: query,
          count: products.size,
          products: products.map { |product| product_json(product) }
        }
      end

      private

      def product_json(product)
        {
          id: product.id,
          canonical_name: product.canonical_name,
          supplier: product.supplier&.name,
          category: product.category_name,
          active: product.active,
          needs_review: product.needs_review
        }
      end
    end
  end
end
