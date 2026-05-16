module Purchasing
  class ProductCatalogNormalizer
    ParsedUnit = Struct.new(
      :package_size,
      :unit_of_measure,
      :standard_unit,
      keyword_init: true
    )

    def initialize(supplier: Supplier.primary)
      @supplier = supplier
      @normalizer = ProductNormalizer.new(supplier: supplier)
      @observation_builder = PriceObservationBuilder.new
    end

    def normalize_all!
      stats = {
        products_before: Product.count,
        line_items_reassigned: 0,
        observations_reassigned: 0,
        reviews_auto_resolved: 0,
        stale_products_removed: 0
      }

      ActiveRecord::Base.transaction do
        supplier.receipt_line_items.items.includes(:product, :price_observation, :normalization_reviews).find_each do |line_item|
          product = normalizer.match_or_create!(line_item, parsed_unit_for(line_item))
          next unless product

          if line_item.product_id != product.id
            line_item.update!(product: product)
            stats[:line_items_reassigned] += 1
          end

          if line_item.price_observation
            if line_item.price_observation.product_id != product.id
              line_item.price_observation.update!(product: product)
              stats[:observations_reassigned] += 1
            end
          else
            observation_builder.create_for!(line_item)
          end

          stats[:reviews_auto_resolved] += auto_resolve_name_reviews!(line_item, product)
        end

        stats[:stale_aliases_removed] = remove_stale_aliases!
        stats[:stale_products_removed] = remove_stale_products!
        PriceSpikeFlagger.new.flag_all!
      end

      stats.merge(
        products_after: Product.count,
        aliases_after: ProductAlias.count,
        products_needing_review: Product.needs_review.count
      )
    end

    private

    attr_reader :supplier, :normalizer, :observation_builder

    def parsed_unit_for(line_item)
      ParsedUnit.new(
        package_size: line_item.parsed_package_size,
        unit_of_measure: line_item.parsed_unit_of_measure,
        standard_unit: line_item.raw_data.dig("parsed_unit", "standard_unit") ||
          line_item.raw_data.dig(:parsed_unit, :standard_unit)
      )
    end

    def auto_resolve_name_reviews!(line_item, product)
      resolved = 0
      line_item.normalization_reviews.pending.where(issue_type: "possible_alias_match").find_each do |review|
        review.update!(
          product: product,
          status: "resolved",
          resolution_notes: "Auto-reviewed after receipt shorthand was normalized to #{product.canonical_name}."
        )
        resolved += 1
      end

      if product.product_category.present? && product.product_category.name != "Other / unknown"
        line_item.normalization_reviews.pending.where(issue_type: "missing_category").find_each do |review|
          review.update!(
            product: product,
            status: "resolved",
            resolution_notes: "Auto-reviewed because normalized product has category #{product.category_name}."
          )
          resolved += 1
        end
      end

      resolved
    end

    def remove_stale_products!
      removed = 0

      supplier.products.includes(:product_aliases).find_each do |product|
        next if product.receipt_line_items.exists?
        next if product.price_observations.exists?
        next unless product.product_aliases.exists?

        detach_reviews_from(product)
        product.product_aliases.destroy_all
        product.destroy!
        removed += 1
      end

      removed
    end

    def remove_stale_aliases!
      removed = 0

      ProductAlias.includes(:product).find_each do |product_alias|
        next if product_alias.product.receipt_line_items.exists?(
          raw_name: product_alias.raw_name,
          raw_sku: product_alias.raw_sku
        )

        product_alias.destroy!
        removed += 1
      end

      removed
    end

    def detach_reviews_from(product)
      NormalizationReview.where(product: product).includes(:receipt_line_item).find_each do |review|
        replacement = review.receipt_line_item.product
        attributes = { product: replacement }

        if review.status == "pending" && replacement.present?
          attributes[:status] = "resolved"
          attributes[:resolution_notes] = "Auto-reviewed after stale raw product was merged into #{replacement.canonical_name}."
        end

        review.update!(attributes)
      end
    end
  end
end
