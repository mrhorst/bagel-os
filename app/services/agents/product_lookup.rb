module Agents
  # Shared product search used by the product-facing commands. Matches against
  # the canonical name and any raw alias name, case-insensitively, so an agent
  # can pass the messy name off a receipt and still land the product.
  module ProductLookup
    module_function

    def search(query, limit: 25)
      pattern = "%#{sanitize(query)}%"
      alias_product_ids = ProductAlias.where("raw_name LIKE ? ESCAPE '\\'", pattern).select(:product_id)

      Product
        .where("canonical_name LIKE ? ESCAPE '\\'", pattern)
        .or(Product.where(id: alias_product_ids))
        .by_name
        .limit(limit)
    end

    # Resolve a single product from an --id flag or a name query, raising a
    # NotFoundError the CLI renders cleanly.
    def resolve(id:, query:)
      if id.present?
        Product.find_by(id: id) ||
          (raise Command::NotFoundError.new("No product with id #{id}", hint: "Run `bin/agent products:search <name>` to find a valid id."))
      elsif query.present?
        search(query, limit: 1).first ||
          (raise Command::NotFoundError.new("No product matching #{query.inspect}", hint: "Run `bin/agent products:search #{query.inspect}` to see candidates."))
      else
        raise Command::UsageError.new("Provide a product name or --id", hint: "Usage: bin/agent price:product <name> [--id N]")
      end
    end

    def sanitize(query)
      query.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
