module Purchasing
  class NormalizationReviewWorkflow
    UNIT_PARSE_RESOLVED = "Resolved after package size and unit were parsed clearly."
    CASE_PACK_RESOLVED = "Resolved after case quantity was paired with an explicit package size and unit."
    MIXED_QUANTITY_RESOLVED = "Resolved after Unit Qty and Case Qty no longer appeared together on the same row."

    def initialize(observation_builder: PriceObservationBuilder.new, name_interpreter: ProductNameInterpreter.new)
      @observation_builder = observation_builder
      @name_interpreter = name_interpreter
    end

    def sync_pending_reviews!(line_item:, intents:)
      intents.each do |intent|
        create_pending_review!(
          line_item: line_item,
          issue_type: intent.issue_type,
          description: intent.description
        )
      end
    end

    def sync_unit_reviews!(line_item:, intents:)
      sync_review_intent!(
        line_item: line_item,
        intents: intents,
        issue_type: "unit_parse",
        resolved_note: UNIT_PARSE_RESOLVED
      )
      sync_review_intent!(
        line_item: line_item,
        intents: intents,
        issue_type: "case_pack",
        resolved_note: CASE_PACK_RESOLVED
      )
      sync_review_intent!(
        line_item: line_item,
        intents: intents,
        issue_type: "mixed_quantity",
        resolved_note: MIXED_QUANTITY_RESOLVED
      )
    end

    def create_pending_review!(line_item:, issue_type:, description:, product: line_item.product)
      line_item.normalization_reviews.find_or_create_by!(issue_type: issue_type, status: "pending") do |review|
        review.product = product
        review.description = description
      end
    end

    def assign_existing_product(review:, product:)
      line_item = review.receipt_line_item

      ActiveRecord::Base.transaction do
        line_item.update!(product: product, needs_review: false)
        ensure_approved_alias!(product, line_item)
        observation_builder.create_for!(line_item)
        review.update!(product: product, status: "resolved", resolution_notes: "Assigned to existing product.")
      end

      product
    end

    def create_product_from_review(review:, canonical_name: nil, product_category_id: nil)
      line_item = review.receipt_line_item
      interpretation = name_interpreter.interpret(line_item.raw_name)
      product_name = canonical_name.presence || interpretation.canonical_name

      ActiveRecord::Base.transaction do
        product = line_item.supplier.products.create!(
          canonical_name: product_name,
          supplier_sku: interpretation.family_group? ? nil : line_item.raw_sku,
          product_category_id: product_category_id,
          purchase_unit: %w[unit case].include?(line_item.purchase_kind) ? line_item.purchase_kind : nil,
          package_size: line_item.parsed_package_size,
          unit_of_measure: line_item.parsed_unit_of_measure,
          standard_unit: standard_unit_for(line_item),
          notes: name_interpreter.notes_for(
            canonical_name: product_name,
            raw_names: [ line_item.raw_name ],
            confidence_score: interpretation.confidence_score,
            basis: interpretation.basis
          ),
          needs_review: false
        )
        ensure_approved_alias!(product, line_item)
        line_item.update!(product: product, needs_review: false)
        observation_builder.create_for!(line_item)
        review.update!(product: product, status: "resolved", resolution_notes: "Created product from review screen.")
        product
      end
    end

    def update_review_status(review:, status:, notes:)
      ActiveRecord::Base.transaction do
        review.update!(
          status: status.presence_in(NormalizationReview::STATUSES) || "resolved",
          resolution_notes: notes
        )
        review.receipt_line_item.update!(needs_review: false) unless review.receipt_line_item.normalization_reviews.pending.exists?
      end
      review
    end

    private

    attr_reader :observation_builder, :name_interpreter

    def sync_review_intent!(line_item:, intents:, issue_type:, resolved_note:)
      if (intent = intents.find { |review_intent| review_intent.issue_type == issue_type })
        create_pending_review!(line_item: line_item, issue_type: intent.issue_type, description: intent.description)
      else
        resolve_pending_reviews!(line_item: line_item, issue_type: issue_type, note: resolved_note)
      end
    end

    def resolve_pending_reviews!(line_item:, issue_type:, note:)
      line_item.normalization_reviews.pending.where(issue_type: issue_type).find_each do |review|
        review.update!(status: "resolved", resolution_notes: note)
      end
    end

    def ensure_approved_alias!(product, line_item)
      product.product_aliases.find_or_create_by!(raw_name: line_item.raw_name, raw_sku: line_item.raw_sku) do |alias_record|
        alias_record.confidence_score = 1.0
        alias_record.approved = true
      end
    end

    def standard_unit_for(line_item)
      line_item.raw_data.dig("calculated", "standard_unit") ||
        line_item.raw_data.dig(:calculated, :standard_unit) ||
        line_item.raw_data.dig("parsed_unit", "standard_unit") ||
        line_item.raw_data.dig(:parsed_unit, :standard_unit)
    end
  end
end
