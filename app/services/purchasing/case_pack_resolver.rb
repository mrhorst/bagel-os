module Purchasing
  class CasePackResolver
    def initialize(scope: SupplierProductPack.approved.case_packs)
      @scope = scope
    end

    def resolve(line_data:, product: nil)
      return unless case_purchase?(line_data)

      supplier = supplier_for(line_data, product)
      return unless supplier

      raw_sku = line_data[:raw_sku].presence
      raw_name = line_data[:raw_name].presence

      candidates = scope.where(supplier: supplier)
      exact_sku_match(candidates, raw_sku) ||
        exact_name_match(candidates, raw_name) ||
        product_match(candidates, product)
    end

    private

    attr_reader :scope

    def case_purchase?(line_data)
      line_data[:raw_case_quantity].to_d.positive? && !line_data[:raw_quantity].to_d.positive?
    end

    def supplier_for(line_data, product)
      line_data[:supplier] || product&.supplier || Supplier.find_by(id: line_data[:supplier_id])
    end

    def exact_sku_match(candidates, raw_sku)
      return if raw_sku.blank?

      candidates.where(raw_sku: raw_sku).order(product_id: :desc, updated_at: :desc).first
    end

    def exact_name_match(candidates, raw_name)
      return if raw_name.blank?

      candidates.where("LOWER(raw_name) = ?", raw_name.downcase).order(product_id: :desc, updated_at: :desc).first
    end

    def product_match(candidates, product)
      return unless product

      candidates.where(product: product, raw_sku: [ nil, "" ], raw_name: [ nil, "" ]).order(updated_at: :desc).first
    end
  end
end
