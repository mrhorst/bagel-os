require "csv"

module Purchasing
  class CasePackFactImporter
    REQUIRED_HEADERS = %w[supplier_name units_per_case].freeze

    def import_file(path)
      rows = CSV.read(path, headers: true)
      missing = REQUIRED_HEADERS - rows.headers.compact
      raise ArgumentError, "Missing required headers: #{missing.join(', ')}" if missing.any?

      stats = { rows_processed: 0, facts_upserted: 0 }

      rows.each do |row|
        next if row.to_h.values.all?(&:blank?)

        stats[:rows_processed] += 1
        upsert_fact!(row)
        stats[:facts_upserted] += 1
      end

      stats
    end

    private

    def upsert_fact!(row)
      supplier = Supplier.find_or_create_by!(name: required(row, "supplier_name"))
      product = product_for(supplier, row["product_name"])
      raw_sku = row["raw_sku"].presence
      raw_name = row["raw_name"].presence
      fact = find_fact(supplier: supplier, product: product, raw_sku: raw_sku, raw_name: raw_name)

      fact.assign_attributes(
        product: product || fact.product,
        purchase_kind: "case",
        units_per_case: decimal(required(row, "units_per_case")),
        inner_unit_label: row["inner_unit_label"].presence || "unit",
        inner_package_size: decimal(row["inner_package_size"]),
        inner_unit_of_measure: row["inner_unit_of_measure"].presence,
        standard_unit: row["standard_unit"].presence || row["inner_unit_of_measure"].presence,
        source: row["source"].presence || "manual",
        source_label: row["source_label"].presence,
        source_snapshot_at: time(row["source_snapshot_at"]),
        approved: boolean(row["approved"], default: true),
        confidence_score: decimal(row["confidence_score"]).presence || BigDecimal("1.0"),
        notes: row["notes"].presence,
        raw_data: row.to_h.compact_blank
      )
      fact.save!
      fact
    end

    def product_for(supplier, product_name)
      return if product_name.blank?

      supplier.products.find_by(canonical_name: product_name)
    end

    def find_fact(supplier:, product:, raw_sku:, raw_name:)
      if raw_sku.present? || raw_name.present?
        SupplierProductPack.find_or_initialize_by(supplier: supplier, raw_sku: raw_sku, raw_name: raw_name)
      else
        SupplierProductPack.find_or_initialize_by(supplier: supplier, product: product, raw_sku: nil, raw_name: nil)
      end
    end

    def required(row, key)
      value = row[key].presence
      raise ArgumentError, "Missing required #{key} in case-pack fact row #{row.to_h.inspect}" if value.blank?

      value
    end

    def decimal(value)
      return if value.blank?

      BigDecimal(value.to_s)
    end

    def time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    end

    def boolean(value, default:)
      return default if value.blank?

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
