module Purchasing
  class ReceiptLineItemEditor
    Result = Struct.new(:line_item, :case_pack, :observation, :success?, keyword_init: true)

    def initialize(recalculator: ReceiptLineItemPriceRecalculator.new)
      @recalculator = recalculator
    end

    def case_pack_for(line_item)
      line_item.case_pack || matching_case_pack(line_item) || build_case_pack(line_item)
    end

    def update_case_pack(line_item:, attributes:)
      case_pack = case_pack_for(line_item)
      assign_case_pack_attributes(case_pack, line_item, attributes)

      unless line_item.purchase_kind == "case"
        case_pack.errors.add(:base, "Case-pack details can only be saved for case purchases.")
        return Result.new(line_item: line_item, case_pack: case_pack, success?: false)
      end

      return Result.new(line_item: line_item, case_pack: case_pack, success?: false) unless case_pack.valid?

      observation = nil
      ActiveRecord::Base.transaction do
        case_pack.save!
        matching_case_purchase_lines(case_pack, line_item).find_each do |matching_line_item|
          recalculated_observation = recalculator.recalculate_line_item!(matching_line_item)
          observation = recalculated_observation if matching_line_item.id == line_item.id
        end
      end

      Result.new(line_item: line_item.reload, case_pack: case_pack, observation: observation, success?: true)
    end

    private

    attr_reader :recalculator

    def matching_case_pack(line_item)
      exact_sku_case_pack(line_item) ||
        exact_name_case_pack(line_item) ||
        product_case_pack(line_item)
    end

    def exact_sku_case_pack(line_item)
      return if line_item.raw_sku.blank?

      line_item.supplier.supplier_product_packs.where(raw_sku: line_item.raw_sku).order(approved: :desc, updated_at: :desc).first
    end

    def exact_name_case_pack(line_item)
      line_item.supplier.supplier_product_packs.where("LOWER(raw_name) = ?", line_item.raw_name.downcase).order(approved: :desc, updated_at: :desc).first
    end

    def product_case_pack(line_item)
      return unless line_item.product

      line_item.supplier.supplier_product_packs.where(product: line_item.product, raw_sku: [ nil, "" ], raw_name: [ nil, "" ]).order(approved: :desc, updated_at: :desc).first
    end

    def matching_case_purchase_lines(case_pack, line_item)
      matching_scope_for(case_pack, line_item)
        .where(line_type: "item")
        .where(raw_quantity: [ nil, "", "0" ])
        .where.not(raw_case_quantity: [ nil, "", "0" ])
        .order(:receipt_id, :line_number)
    end

    def matching_scope_for(case_pack, line_item)
      scope = ReceiptLineItem.where(supplier: line_item.supplier)

      if case_pack.raw_sku.present?
        scope.where(raw_sku: case_pack.raw_sku)
      elsif case_pack.raw_name.present?
        scope.where("LOWER(raw_name) = ?", case_pack.raw_name.downcase)
      elsif case_pack.product.present?
        scope.where(product: case_pack.product)
      else
        ReceiptLineItem.none
      end
    end

    def build_case_pack(line_item)
      line_item.supplier.supplier_product_packs.build(
        product: line_item.product,
        raw_sku: line_item.raw_sku.presence,
        raw_name: line_item.raw_name,
        purchase_kind: "case",
        inner_package_size: line_item.parsed_package_size,
        inner_unit_of_measure: line_item.parsed_unit_of_measure,
        standard_unit: line_item.parsed_unit_of_measure,
        source: "manual",
        approved: true,
        confidence_score: 1
      )
    end

    def assign_case_pack_attributes(case_pack, line_item, attributes)
      case_pack.assign_attributes(
        product: line_item.product || case_pack.product,
        raw_sku: case_pack.raw_sku.presence || line_item.raw_sku.presence,
        raw_name: case_pack.raw_name.presence || line_item.raw_name,
        purchase_kind: "case",
        units_per_case: attributes[:units_per_case],
        inner_unit_label: attributes[:inner_unit_label],
        inner_package_size: attributes[:inner_package_size],
        inner_unit_of_measure: attributes[:inner_unit_of_measure],
        standard_unit: attributes[:standard_unit],
        source: "manual",
        source_label: "receipt line edit",
        approved: true,
        confidence_score: 1,
        notes: attributes[:notes],
        raw_data: case_pack.raw_data.merge(
          "edited_from_receipt_line_item_id" => line_item.id,
          "edited_from_import_batch_id" => line_item.import_batch_id,
          "edited_at" => Time.current.iso8601
        )
      )
    end
  end
end
