module Purchasing
  class OrderGuideTextParser
    SUBCATEGORY_HEADINGS = [
      "Bagels",
      "Sliced Bread",
      "Sodas"
    ].freeze

    def parse(text, guide_type:)
      rows = []
      current_section = nil
      current_subcategory = nil

      clean_text(text).each_line do |line|
        raw_line = line.delete("\f").rstrip
        stripped = raw_line.strip
        next if skip_line?(stripped)

        if (section_name = section_name_from(stripped))
          current_section = section_name
          current_subcategory = nil
          next
        end

        next if current_section.blank?

        fields = fields_for(stripped)
        next if fields.empty?

        sku = nil
        if fields.size >= 2 && sku_token?(fields.first)
          sku = fields.shift
        end

        item_name = fields.shift.to_s.squish
        next if item_name.blank?

        if subcategory_heading?(item_name, fields)
          current_subcategory = item_name
          next
        end

        rows << row_for(
          guide_type: guide_type,
          section_name: current_section,
          subcategory: current_subcategory,
          item_name: item_name,
          sku: sku,
          fields: fields,
          raw_line: stripped,
          position: rows.size + 1
        )
      end

      rows
    end

    private

    def clean_text(text)
      text.to_s.gsub("\r\n", "\n").gsub("\r", "\n")
    end

    def skip_line?(line)
      line.blank? ||
        line.match?(/\A.+-\s+.*Order Guide\b/i) ||
        line.start_with?("Sunday =") ||
        line.start_with?("Thursday =") ||
        line.start_with?("Monday run") ||
        line.start_with?("Friday run") ||
        line == "DATE"
    end

    def section_name_from(line)
      match = line.match(/\A(?<name>[A-Za-z0-9&, \/()-]+?)\s+Par\s+Pack Qty\b/i)
      match&.[](:name)&.squish
    end

    def fields_for(line)
      line.gsub(/\s{2,}/, "\t").split("\t").map(&:squish).reject(&:blank?)
    end

    def sku_token?(value)
      value.match?(/\A[A-Z0-9]{2,}\z/) && value.match?(/[A-Z]/) && value.match?(/\d/)
    end

    def subcategory_heading?(item_name, fields)
      fields.empty? && SUBCATEGORY_HEADINGS.include?(item_name)
    end

    def row_for(guide_type:, section_name:, subcategory:, item_name:, sku:, fields:, raw_line:, position:)
      {
        guide_type: guide_type,
        section_name: section_name,
        subcategory: subcategory,
        item_name: item_name,
        guide_sku: sku,
        par_text: fields[0],
        pack_quantity: fields[1],
        sunday_target: guide_type == "weekly" ? fields[2] : nil,
        thursday_target: guide_type == "weekly" ? fields[3] : nil,
        raw_line: raw_line,
        position: position
      }
    end
  end
end
