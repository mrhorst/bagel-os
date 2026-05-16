require "digest"

module Purchasing
  class CsvImporter
    attr_reader :supplier, :parser, :unit_parser, :price_calculator, :observation_builder

    def initialize(supplier: Supplier.primary)
      @supplier = supplier
      @parser = ReceiptCsvParser.new
      @unit_parser = UnitParser.new
      @price_calculator = PriceCalculator.new
      @observation_builder = PriceObservationBuilder.new
    end

    def import_file(path, source_filename: File.basename(path))
      checksum = Digest::SHA256.file(path).hexdigest
      existing_batch = ImportBatch.find_by(file_checksum: checksum)
      return result(existing_batch, skipped: true, message: "Already imported by checksum.") if existing_batch

      parsed = parser.parse(path, source_filename: source_filename)
      normalizer = ProductNormalizer.new(supplier: supplier)

      ActiveRecord::Base.transaction do
        batch = supplier.import_batches.create!(
          source_filename: source_filename,
          source_path: path.to_s,
          file_checksum: checksum,
          imported_at: Time.current,
          status: parsed[:errors].any? ? "failed" : "pending",
          rows_processed: parsed[:rows_processed],
          rows_failed: parsed[:errors].size,
          validation_summary: summary_for(parsed)
        )

        if parsed[:errors].any?
          batch.update!(notes: parsed[:errors].join("\n"))
          return result(batch, skipped: false, message: "Import failed parser validation.")
        end

        if parsed[:receipt_number].blank?
          batch.update!(status: "failed", rows_failed: parsed[:rows_processed], notes: "Receipt number missing.")
          return result(batch, skipped: false, message: "Receipt number missing.")
        end

        if supplier.receipts.exists?(receipt_number: parsed[:receipt_number])
          batch.update!(status: "skipped", notes: "Receipt #{parsed[:receipt_number]} already exists.")
          return result(batch, skipped: true, message: "Already imported by receipt number.")
        end

        receipt = create_receipt!(batch, parsed)
        imported_count = 0

        parsed[:line_items].each do |line_data|
          parsed_unit = unit_parser.parse(
            line_data[:raw_name],
            raw_quantity: line_data[:raw_quantity],
            raw_case_quantity: line_data[:raw_case_quantity]
          )
          calculated = price_calculator.calculate(line_data, parsed_unit)
          line_item = create_line_item!(receipt, batch, line_data, parsed_unit, calculated)
          product = normalizer.match_or_create!(line_item, parsed_unit)
          line_item.update!(product: product) if product
          create_reviews!(line_item, parsed_unit, calculated)
          observation_builder.create_for!(line_item)
          imported_count += 1
        end

        batch.update!(
          status: "imported",
          rows_imported: imported_count,
          rows_failed: parsed[:errors].size,
          validation_summary: summary_for(parsed).merge(
            line_items_created: imported_count,
            products_total: Product.count,
            aliases_total: ProductAlias.count,
            price_observations_total: PriceObservation.count,
            rows_needing_review: ReceiptLineItem.needs_review.count
          )
        )
        PriceSpikeFlagger.new.flag_all!
        result(batch, skipped: false, message: "Imported #{imported_count} receipt line items.")
      end
    rescue ActiveRecord::RecordInvalid => error
      failed_batch = supplier.import_batches.create!(
        source_filename: source_filename,
        source_path: path.to_s,
        file_checksum: checksum || SecureRandom.uuid,
        imported_at: Time.current,
        status: "failed",
        notes: error.message,
        rows_failed: 1
      )
      result(failed_batch, skipped: false, message: error.message)
    end

    private

    def create_receipt!(batch, parsed)
      supplier.receipts.create!(
        import_batch: batch,
        receipt_number: parsed[:receipt_number],
        purchased_at: parsed[:purchased_at],
        subtotal: parsed[:totals]["sub_total"],
        tax: parsed[:totals]["tax"],
        total: parsed[:totals]["total"],
        raw_data: {
          terminal: parsed[:terminal],
          store_name: parsed[:store_name],
          customer_number: parsed[:customer_number],
          raw_header: parsed[:raw_header]
        }
      )
    end

    def create_line_item!(receipt, batch, line_data, parsed_unit, calculated)
      needs_review = line_data[:line_type] != "item" ||
        parsed_unit.needs_review ||
        calculated[:standard_unit_price].blank?

      receipt.receipt_line_items.create!(
        supplier: supplier,
        import_batch: batch,
        line_number: line_data[:line_number],
        line_type: line_data[:line_type],
        raw_name: line_data[:raw_name],
        raw_sku: line_data[:raw_sku],
        raw_quantity: line_data[:raw_quantity],
        raw_case_quantity: line_data[:raw_case_quantity],
        raw_unit: parsed_unit.unit_of_measure,
        raw_package_description: line_data[:raw_name],
        quantity: calculated[:quantity],
        package_price: calculated[:package_price],
        line_total: line_data[:line_total],
        parsed_package_size: parsed_unit.package_size,
        parsed_unit_of_measure: parsed_unit.unit_of_measure,
        confidence_score: parsed_unit.confidence || 0,
        needs_review: needs_review,
        row_checksum: Digest::SHA256.hexdigest(line_data[:raw_data].to_json),
        raw_data: line_data[:raw_data].merge(
          parsed_unit: parsed_unit.to_h,
          calculated: calculated
        )
      )
    end

    def create_reviews!(line_item, parsed_unit, calculated)
      if line_item.line_type == "coupon"
        create_review!(line_item, "coupon", "Coupon/discount row imported for traceability but not mapped to a product price.")
      end

      if parsed_unit.needs_review
        create_review!(line_item, "unit_parse", parsed_unit.notes || "Package size or unit needs review.")
      end

      if line_item.product&.product_category&.name == "Other / unknown"
        create_review!(line_item, "missing_category", "Product category could not be classified confidently.")
      end

      if line_item.raw_case_quantity.to_d.positive? && calculated[:standard_unit_price].blank?
        create_review!(line_item, "case_pack", "Case quantity is present, but case pack size/unit is not clear enough to calculate comparable unit price.")
      end
    end

    def create_review!(line_item, issue_type, description)
      line_item.normalization_reviews.find_or_create_by!(issue_type: issue_type, status: "pending") do |review|
        review.product = line_item.product
        review.description = description
      end
    end

    def summary_for(parsed)
      {
        source_filename: parsed[:source_filename],
        receipt_number: parsed[:receipt_number],
        purchased_at: parsed[:purchased_at]&.iso8601,
        rows_processed: parsed[:rows_processed],
        item_rows_found: parsed[:line_items].count { |row| row[:line_type] == "item" },
        coupon_rows_found: parsed[:line_items].count { |row| row[:line_type] == "coupon" },
        skipped_rows: parsed[:skipped_rows]&.size.to_i,
        errors: parsed[:errors]
      }
    end

    def result(batch, skipped:, message:)
      {
        batch: batch,
        skipped: skipped,
        message: message,
        validation_summary: batch.validation_summary
      }
    end
  end
end
