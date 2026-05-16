module Purchasing
  class OrderGuideMatchRefresher
    def initialize(matcher: ProductNameMatcher.new)
      @matcher = matcher
    end

    def refresh!
      stats = { reviewed: 0, linked: 0 }

      OrderGuideItem.active.includes(:inventory_item).find_each do |guide_item|
        stats[:reviewed] += 1
        match = matcher.match(
          guide_item.item_name,
          context: {
            section_name: guide_item.section_name,
            subcategory: guide_item.subcategory
          }
        )

        unless match.confident?
          mark_for_review!(guide_item, match)
          next
        end

        inventory_item = inventory_item_for(guide_item, match.product)
        raw_data = guide_item.raw_data.merge(
          "match_basis" => match.basis,
          "suggested_product_id" => nil,
          "suggested_product_name" => nil
        )

        inventory_item.update!(
          product: match.product,
          preferred_supplier: match.product.supplier,
          needs_review: false,
          raw_data: inventory_item.raw_data.merge("match_basis" => match.basis)
        )
        guide_item.update!(
          inventory_item: inventory_item,
          needs_review: false,
          match_confidence: match.confidence,
          raw_data: raw_data
        )
        stats[:linked] += 1
      end

      stats
    end

    private

    attr_reader :matcher

    def inventory_item_for(guide_item, product)
      existing_for_product = InventoryItem.find_by(product: product)
      return existing_for_product if reusable_for_guide_item?(existing_for_product, guide_item, product)
      return guide_item.inventory_item if reusable_for_guide_item?(guide_item.inventory_item, guide_item, product)

      section = InventorySection.find_or_create_by!(name: guide_item.section_name)
      InventoryItem.find_or_create_by!(key: InventoryItem.key_for(product.canonical_name)) do |item|
        item.name = guide_item.item_name
        item.inventory_section = section
        item.category = guide_item.section_name
        item.subcategory = guide_item.subcategory
        item.position = guide_item.position
      end
    end

    def reusable_for_guide_item?(inventory_item, guide_item, product)
      return false unless inventory_item
      return true if inventory_item.product_id == product.id && name_match?(inventory_item.name, guide_item.item_name)
      return true if name_match?(inventory_item.name, guide_item.item_name)
      return true if name_match?(inventory_item.name, product.canonical_name) && !shared_with_other_guide_rows?(inventory_item, guide_item)

      false
    end

    def shared_with_other_guide_rows?(inventory_item, guide_item)
      inventory_item.order_guide_items.active.where.not(id: guide_item.id).exists?
    end

    def name_match?(left, right)
      InventoryItem.key_for(left) == InventoryItem.key_for(right)
    end

    def mark_for_review!(guide_item, match)
      raw_data = guide_item.raw_data.merge(
        "match_basis" => match.basis,
        "suggested_product_id" => match.suggested_product&.id,
        "suggested_product_name" => match.suggested_product&.canonical_name
      )

      guide_item.inventory_item&.update!(product: nil, needs_review: true)
      guide_item.update!(
        needs_review: true,
        match_confidence: match.confidence,
        raw_data: raw_data
      )
    end
  end
end
