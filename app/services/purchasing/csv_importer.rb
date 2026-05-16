module Purchasing
  class CsvImporter
    attr_reader :supplier, :parser, :line_normalizer, :observation_builder, :review_workflow

    def initialize(supplier: Supplier.primary)
      @supplier = supplier
      @parser = ReceiptCsvParser.new
      @line_normalizer = ReceiptLineNormalizer.new
      @observation_builder = PriceObservationBuilder.new
      @review_workflow = NormalizationReviewWorkflow.new
    end

    def import_file(path, source_filename: File.basename(path))
      checksum = Digest::SHA256.file(path).hexdigest
      existing_batch = ImportBatch.find_by(file_checksum: checksum)
      return result(existing_batch, skipped: true, message: "Already imported by checksum.") if existing_batch

      parsed = parser.parse(path, source_filename: source_filename)
      product_normalizer = ProductNormalizer.new(supplier: supplier)

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
          line_data = line_data.merge(supplier: supplier)
          normalized_line = line_normalizer.normalize(line_data: line_data)
          line_item = create_line_item!(receipt, batch, normalized_line)
          product = product_normalizer.match_or_create!(line_item, normalized_line.parsed_unit)
          if product
            normalized_line = line_normalizer.normalize(line_data: line_data, existing_raw_data: line_item.raw_data, product: product)
            line_item.update!(product: product, **normalized_line.normalized_attributes)
          end
          create_reviews!(line_item, normalized_line)
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

    def create_line_item!(receipt, batch, normalized_line)
      receipt.receipt_line_items.create!(
        supplier: supplier,
        import_batch: batch,
        **normalized_line.line_item_attributes
      )
    end

    def create_reviews!(line_item, normalized_line)
      review_workflow.sync_pending_reviews!(
        line_item: line_item,
        intents: normalized_line.review_intents(product: line_item.product)
      )
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
