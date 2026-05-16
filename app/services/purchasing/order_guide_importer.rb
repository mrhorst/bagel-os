require "digest"

module Purchasing
  class OrderGuideImporter
    Result = Struct.new(:skipped, :message, :rows_imported, :import, keyword_init: true)

    def initialize(extractor: OrderGuideTextExtractor.new, parser: OrderGuideTextParser.new, matcher: ProductNameMatcher.new, linking: nil)
      @extractor = extractor
      @parser = parser
      @linking = linking || OrderGuideLinking.new(matcher: matcher)
    end

    def import_file(path, guide_type: nil)
      path = Pathname(path)
      checksum = Digest::SHA256.file(path).hexdigest
      existing_import = OrderGuideImport.find_by(file_checksum: checksum)
      return skipped_result(existing_import) if existing_import

      guide_type ||= guide_type_for(path)
      text = extractor.extract(path)
      rows = parser.parse(text, guide_type: guide_type)
      import = nil

      ActiveRecord::Base.transaction do
        import = OrderGuideImport.create!(
          source_filename: path.basename.to_s,
          source_path: path.to_s,
          guide_type: guide_type,
          file_checksum: checksum,
          imported_at: Time.current,
          status: "pending",
          raw_text: text
        )

        OrderGuideItem.active.where(guide_type: guide_type).update_all(active: false, updated_at: Time.current)
        rows.each { |row| import_row!(import, row) }
        refresh_inventory_item_frequencies!
        import.update!(
          status: "imported",
          rows_imported: import.order_guide_items.count,
          validation_summary: validation_summary(import)
        )
      end

      Result.new(skipped: false, message: "Imported #{import.rows_imported} #{guide_type} guide rows.", rows_imported: import.rows_imported, import: import)
    rescue StandardError => error
      import&.update(status: "failed", notes: error.message)
      raise
    end

    private

    attr_reader :extractor, :parser, :linking

    def skipped_result(existing_import)
      Result.new(
        skipped: true,
        message: "#{existing_import.source_filename} was already imported on #{existing_import.imported_at.to_fs(:db)}.",
        rows_imported: 0,
        import: existing_import
      )
    end

    def guide_type_for(path)
      filename = path.basename.to_s.downcase
      return "daily" if filename.include?("daily")
      return "weekly" if filename.include?("weekly") || filename.include?("order guide")

      raise ArgumentError, "Could not infer guide type from #{path.basename}; pass guide_type: 'daily' or 'weekly'."
    end

    def import_row!(import, row)
      linking.link_row!(import: import, row: row)
    end

    def refresh_inventory_item_frequencies!
      InventoryItem.includes(:order_guide_items).find_each do |item|
        guide_types = item.order_guide_items.active.distinct.pluck(:guide_type).sort
        frequency =
          case guide_types
          when [ "daily", "weekly" ]
            "both"
          when [ "daily" ], [ "weekly" ]
            guide_types.first
          else
            "manual"
          end

        item.update!(guide_frequency: frequency, active: guide_types.any? || item.inventory_count_lines.exists?)
      end
    end

    def validation_summary(import)
      items = import.order_guide_items
      {
        rows_imported: items.count,
        linked_to_receipt_product: items.joins(inventory_item: :product).count,
        needs_review: items.needs_review.count
      }
    end
  end
end
