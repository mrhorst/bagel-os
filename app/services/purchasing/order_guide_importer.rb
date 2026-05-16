require "digest"

module Purchasing
  class OrderGuideImporter
    AUTO_LINK_THRESHOLD = 0.9

    Result = Struct.new(:skipped, :message, :rows_imported, :import, keyword_init: true)

    def initialize(extractor: OrderGuideTextExtractor.new, parser: OrderGuideTextParser.new, matcher: ProductNameMatcher.new)
      @extractor = extractor
      @parser = parser
      @matcher = matcher
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

    attr_reader :extractor, :parser, :matcher

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
      section = section_for(row[:section_name])
      match = matcher.match(row[:item_name], context: row)
      product = match.confident? ? match.product : nil
      inventory_item = inventory_item_for(row, section, product)
      raw_data = {
        "match_basis" => match.basis,
        "suggested_product_id" => match.suggested_product&.id,
        "suggested_product_name" => match.suggested_product&.canonical_name
      }.compact

      inventory_item.update!(
        name: inventory_item.name.presence || row[:item_name],
        inventory_section: section,
        product: product || inventory_item.product,
        preferred_supplier: (product&.supplier || inventory_item.preferred_supplier),
        category: row[:section_name],
        subcategory: row[:subcategory],
        pack_size: inventory_item.pack_size.presence || row[:pack_quantity],
        count_unit: inventory_item.count_unit.presence || row[:pack_quantity],
        position: row[:position],
        active: true,
        needs_review: product.blank?,
        raw_data: inventory_item.raw_data.merge(raw_data)
      )

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
        raw_data: raw_data
      )
    end

    def section_for(section_name)
      InventorySection.find_or_create_by!(name: section_name) do |section|
        section.position = InventorySection.count + 1
      end
    end

    def inventory_item_for(row, section, product)
      return InventoryItem.find_by(product: product) if product && InventoryItem.exists?(product: product)

      key_source = product ? product.canonical_name : [ section.name, row[:subcategory], row[:item_name] ].compact.join(" ")
      InventoryItem.find_or_initialize_by(key: InventoryItem.key_for(key_source)) do |item|
        item.name = row[:item_name]
      end
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
