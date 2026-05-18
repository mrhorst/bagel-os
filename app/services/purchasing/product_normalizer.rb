module Purchasing
  class ProductNormalizer
    def initialize(supplier:)
      @supplier = supplier
      @category_classifier = CategoryClassifier.new
      @name_interpreter = ProductNameInterpreter.new
    end

    def match_or_create!(line_item, parsed_unit)
      return if line_item.line_type != "item"

      interpretation = name_interpreter.interpret(line_item.raw_name)
      category = category_classifier.category_for(line_item.raw_name)
      decision = product_decision_for(line_item, interpretation)
      product = decision&.auto_link? ? decision.product : build_product(line_item, parsed_unit, interpretation, category)
      ensure_alias!(product, line_item, interpretation)
      refresh_product!(product, line_item, parsed_unit, interpretation, category)
      flag_possible_match!(product, line_item, interpretation) if product.previously_new_record?
      product
    end

    private

    attr_reader :supplier, :category_classifier, :name_interpreter

    def product_decision_for(line_item, interpretation)
      if (product = find_product(line_item, interpretation))
        ProductMatchDecision.new(
          product: product,
          confidence: 0.98,
          basis: "receipt product identity rule",
          source: "receipt"
        )
      end
    end

    def find_product(line_item, interpretation)
      canonical_product = supplier.products.where(canonical_name: interpretation.canonical_name).to_a.min_by do |product|
        product.supplier_sku.present? ? 1 : 0
      end
      return canonical_product if canonical_product

      if line_item.raw_sku.present? && !interpretation.family_group?
        product = supplier.products.find_by(supplier_sku: line_item.raw_sku)
        return product if product
      end

      alias_record = ProductAlias.approved
        .joins(:product)
        .where(products: { supplier_id: supplier.id })
        .find_by(raw_name: line_item.raw_name, raw_sku: line_item.raw_sku)

      return alias_record&.product unless interpretation.family_group?
      return alias_record.product if alias_record&.product&.canonical_name == interpretation.canonical_name

      nil
    end

    def build_product(line_item, parsed_unit, interpretation, category)
      supplier.products.create!(
        canonical_name: interpretation.canonical_name,
        supplier_sku: interpretation.family_group? ? nil : line_item.raw_sku,
        product_category: category,
        purchase_unit: interpretation.family_group? ? nil : purchase_unit_for(line_item),
        package_size: interpretation.family_group? ? nil : parsed_unit.package_size,
        unit_of_measure: interpretation.family_group? ? nil : parsed_unit.unit_of_measure,
        standard_unit: interpretation.family_group? ? nil : parsed_unit.standard_unit,
        notes: name_interpreter.notes_for(
          canonical_name: interpretation.canonical_name,
          raw_names: [ line_item.raw_name ],
          confidence_score: interpretation.confidence_score,
          basis: interpretation.basis
        ),
        needs_review: product_needs_review?(category, interpretation)
      )
    end

    def ensure_alias!(product, line_item, interpretation)
      product.product_aliases.find_or_create_by!(
        raw_name: line_item.raw_name,
        raw_sku: line_item.raw_sku
      ) do |alias_record|
        alias_record.confidence_score = interpretation.confidence_score
        alias_record.approved = true
      end
    end

    def refresh_product!(product, line_item, parsed_unit, interpretation, category)
      raw_names = product.product_aliases.reload.map(&:raw_name)
      sku_values = product.product_aliases.map(&:raw_sku).compact_blank.uniq

      refresh_canonical_name!(product, interpretation)
      refresh_category!(product, category)
      refresh_supplier_sku!(product, line_item, interpretation, sku_values)
      refresh_package_fields!(product, line_item, parsed_unit, interpretation)
      refresh_notes!(product, raw_names, interpretation)
      product.needs_review = product_needs_review?(product.product_category, interpretation)
      product.save! if product.changed?
    end

    def refresh_canonical_name!(product, interpretation)
      return if product.canonical_name == interpretation.canonical_name
      return if product.notes.present? && !product.needs_review?

      product.canonical_name = interpretation.canonical_name
    end

    def refresh_category!(product, category)
      return if product.product_category.present? && product.product_category.name != "Other / unknown"

      product.product_category = category
    end

    def refresh_supplier_sku!(product, line_item, interpretation, sku_values)
      product.supplier_sku = nil if interpretation.family_group? || sku_values.size > 1
      product.supplier_sku ||= line_item.raw_sku if !interpretation.family_group? && sku_values.size <= 1
    end

    def refresh_package_fields!(product, line_item, parsed_unit, interpretation)
      if interpretation.family_group?
        clear_package_fields!(product)
      else
        fill_package_fields!(product, line_item, parsed_unit)
      end
    end

    def clear_package_fields!(product)
      product.purchase_unit = nil
      product.package_size = nil
      product.unit_of_measure = nil
      product.standard_unit = nil
    end

    def fill_package_fields!(product, line_item, parsed_unit)
      product.purchase_unit ||= purchase_unit_for(line_item)
      product.package_size ||= parsed_unit.package_size
      product.unit_of_measure ||= parsed_unit.unit_of_measure
      product.standard_unit ||= parsed_unit.standard_unit
    end

    def refresh_notes!(product, raw_names, interpretation)
      product.notes = name_interpreter.notes_for(
        canonical_name: product.canonical_name,
        raw_names: raw_names,
        confidence_score: interpretation.confidence_score,
        basis: interpretation.basis
      )
    end

    def product_needs_review?(category, interpretation)
      category.blank? || category.name == "Other / unknown" || !interpretation.auto_review?
    end

    def purchase_unit_for(line_item)
      return line_item.purchase_kind if %w[unit case].include?(line_item.purchase_kind)

      nil
    end

    def flag_possible_match!(product, line_item, interpretation)
      return if interpretation.auto_review?

      possible_match = supplier.products
        .where.not(id: product.id)
        .detect { |candidate| similarity(candidate.canonical_name, line_item.raw_name) >= 0.78 }

      return unless possible_match

      line_item.normalization_reviews.find_or_create_by!(
        issue_type: "possible_alias_match",
        status: "pending"
      ) do |review|
        review.product = possible_match
        review.description = "Possible match with #{possible_match.canonical_name}; not auto-merged because names/SKUs are not exact."
      end
    end

    def similarity(left, right)
      left_tokens = tokens(left)
      right_tokens = tokens(right)
      return 0 if left_tokens.empty? || right_tokens.empty?

      (left_tokens & right_tokens).size.to_f / (left_tokens | right_tokens).size
    end

    def tokens(value)
      value.to_s.upcase.scan(/[A-Z0-9]+/) - %w[CQ JF RD ST CM PC FZ]
    end
  end
end
