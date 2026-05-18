module Purchasing
  class OrderGuideLinking
    CONFIDENT_MATCH_THRESHOLD = BigDecimal("0.9")

    Result = Struct.new(
      :guide_item,
      :inventory_item,
      :match,
      :linked,
      keyword_init: true
    ) do
      def linked?
        linked
      end
    end

    def initialize(matcher: ProductNameMatcher.new)
      @matcher = matcher
    end

    def link_row!(import:, row:)
      section = section_for(row[:section_name])
      match = match_row(row)
      product = confident_match?(match) ? match.product : nil
      inventory_item = inventory_item_for(row: row, guide_item: nil, section: section, product: product)

      apply_inventory_item!(inventory_item, row: row, section: section, product: product, match: match)
      apply_order_guide_membership!(inventory_item, row)
      guide_item = create_guide_item!(import, row, inventory_item, match, product)

      Result.new(guide_item: guide_item, inventory_item: inventory_item, match: match, linked: product.present?)
    end

    def refresh_item!(guide_item)
      row = row_for(guide_item)
      match = match_row(row)

      unless confident_match?(match)
        mark_for_review!(guide_item, match)
        return Result.new(guide_item: guide_item, inventory_item: guide_item.inventory_item, match: match, linked: false)
      end

      section = section_for(guide_item.section_name)
      inventory_item = inventory_item_for(row: row, guide_item: guide_item, section: section, product: match.product)
      apply_inventory_item!(inventory_item, row: row, section: section, product: match.product, match: match)
      apply_order_guide_membership!(inventory_item, row)
      guide_item.update!(
        inventory_item: inventory_item,
        needs_review: false,
        match_confidence: match.confidence,
        raw_data: guide_item.raw_data.merge(match_metadata(match, linked: true))
      )

      Result.new(guide_item: guide_item, inventory_item: inventory_item, match: match, linked: true)
    end

    def refresh_all!(scope: OrderGuideItem.active)
      stats = { reviewed: 0, linked: 0 }

      scope.includes(:inventory_item).find_each do |guide_item|
        stats[:reviewed] += 1
        result = refresh_item!(guide_item)
        stats[:linked] += 1 if result.linked?
      end

      stats
    end

    def covered_product_ids(scope: OrderGuideItem.active)
      linked_ids = InventoryItem.active.where.not(product_id: nil).pluck(:product_id)
      matched_ids = scope.to_a.filter_map do |guide_item|
        match = match_row(row_for(guide_item))
        match.product.id if confident_match?(match)
      end

      (linked_ids + matched_ids).uniq
    end

    def covered_by_guide_name?(product, scope: OrderGuideItem.active)
      scope.to_a.any? do |guide_item|
        normalized_product_names(product).include?(matcher.normalize(guide_item.item_name))
      end
    end

    private

    attr_reader :matcher

    def match_row(row)
      matcher.match(
        row[:item_name],
        context: {
          section_name: row[:section_name],
          subcategory: row[:subcategory]
        }
      )
    end

    def confident_match?(match)
      match.product.present? && match.confidence.to_d >= CONFIDENT_MATCH_THRESHOLD
    end

    def create_guide_item!(import, row, inventory_item, match, product)
      import.order_guide_items.create!(
        inventory_item: inventory_item,
        guide_type: row[:guide_type],
        section_name: row[:section_name],
        subcategory: row[:subcategory],
        item_name: row[:item_name],
        guide_sku: row[:guide_sku],
        par_text: row[:par_text],
        pack_quantity: row[:pack_quantity],
        sunday_target: row[:sunday_target],
        thursday_target: row[:thursday_target],
        raw_line: row[:raw_line],
        position: row[:position],
        active: true,
        needs_review: product.blank?,
        match_confidence: match.confidence,
        raw_data: match_metadata(match, linked: product.present?).compact
      )
    end

    def apply_inventory_item!(inventory_item, row:, section:, product:, match:)
      inventory_item.update!(
        name: inventory_item.name.presence || row[:item_name],
        inventory_section: section,
        product: product,
        preferred_supplier: product&.supplier || inventory_item.preferred_supplier,
        category: row[:section_name],
        subcategory: row[:subcategory],
        pack_size: inventory_item.pack_size.presence || row[:pack_quantity],
        count_unit: inventory_item.count_unit.presence || row[:pack_quantity],
        position: row[:position],
        active: true,
        needs_review: product.blank?,
        raw_data: inventory_item.raw_data.merge(match_metadata(match, linked: product.present?).compact)
      )
    end

    def apply_order_guide_membership!(inventory_item, row)
      guide = OrderGuide.named!(OrderGuide.name_for_guide_type(row[:guide_type]))
      inventory_item.add_to_order_guide!(
        guide,
        primary: inventory_item.primary_order_guide.blank?,
        position: row[:position]
      )
    end

    def inventory_item_for(row:, guide_item:, section:, product:)
      if product
        existing_for_product = InventoryItem.find_by(product: product)
        return existing_for_product if guide_item.blank? && existing_for_product
        return existing_for_product if reusable_for_guide_item?(existing_for_product, guide_item, product)
        return guide_item.inventory_item if reusable_for_guide_item?(guide_item&.inventory_item, guide_item, product)
      end

      key_source = product ? product.canonical_name : [ section.name, row[:subcategory], row[:item_name] ].compact.join(" ")
      InventoryItem.find_or_initialize_by(key: InventoryItem.key_for(key_source)) do |item|
        item.name = row[:item_name]
      end
    end

    def reusable_for_guide_item?(inventory_item, guide_item, product)
      return false unless inventory_item && guide_item

      guide_name_matches = name_match?(inventory_item.name, guide_item.item_name)
      product_name_matches = name_match?(inventory_item.name, product.canonical_name)

      (inventory_item.product_id == product.id && guide_name_matches) ||
        guide_name_matches ||
        (product_name_matches && !shared_with_other_guide_rows?(inventory_item, guide_item))
    end

    def shared_with_other_guide_rows?(inventory_item, guide_item)
      inventory_item.order_guide_items.active.where.not(id: guide_item.id).exists?
    end

    def name_match?(left, right)
      InventoryItem.key_for(left) == InventoryItem.key_for(right)
    end

    def normalized_product_names(product)
      [
        matcher.normalize(product.canonical_name),
        *product.product_aliases.map { |product_alias| matcher.normalize(product_alias.raw_name) }
      ].uniq
    end

    def mark_for_review!(guide_item, match)
      guide_item.inventory_item&.update!(product: nil, needs_review: true)
      guide_item.update!(
        needs_review: true,
        match_confidence: match.confidence,
        raw_data: guide_item.raw_data.merge(match_metadata(match, linked: false).compact)
      )
    end

    def match_metadata(match, linked:)
      {
        "match_basis" => match.basis,
        "suggested_product_id" => linked ? nil : match.suggested_product&.id,
        "suggested_product_name" => linked ? nil : match.suggested_product&.canonical_name
      }
    end

    def row_for(guide_item)
      {
        guide_type: guide_item.guide_type,
        section_name: guide_item.section_name,
        subcategory: guide_item.subcategory,
        item_name: guide_item.item_name,
        guide_sku: guide_item.guide_sku,
        par_text: guide_item.par_text,
        pack_quantity: guide_item.pack_quantity,
        sunday_target: guide_item.sunday_target,
        thursday_target: guide_item.thursday_target,
        raw_line: guide_item.raw_line,
        position: guide_item.position
      }
    end

    def section_for(section_name)
      InventorySection.find_or_create_by!(name: section_name) do |section|
        section.position = InventorySection.count + 1
      end
    end
  end
end
