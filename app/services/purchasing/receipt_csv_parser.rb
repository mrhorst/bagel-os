require "csv"
require "digest"

module Purchasing
  class ReceiptCsvParser
    ITEM_HEADER = [ "UPC", "Description", "Unit Qty", "Case Qty", "Price" ].freeze

    def parse(path, source_filename: File.basename(path))
      rows = CSV.read(path, encoding: "bom|utf-8")
      header_index = rows.index { |row| row == ITEM_HEADER }
      errors = []

      unless header_index
        return {
          source_filename: source_filename,
          rows_processed: rows.length,
          line_items: [],
          totals: {},
          errors: [ "Could not find expected receipt item header." ],
          raw_header: rows.first(6)
        }
      end

      invoice_row = rows.find { |row| row&.first.to_s.start_with?("Invoice:") }
      invoice_data = parse_invoice_row(invoice_row)
      data_rows = rows[(header_index + 1)..] || []
      totals = {}
      line_items = []
      skipped_rows = []

      data_rows.each_with_index do |row, offset|
        line_number = header_index + offset + 2

        if row.blank? || row.length.zero?
          skipped_rows << { line_number: line_number, reason: "blank" }
          next
        end

        unless row.length == 5
          errors << "Line #{line_number}: expected 5 columns, got #{row.length}."
          skipped_rows << { line_number: line_number, row: row, reason: "wrong_column_count" }
          next
        end

        upc, description, unit_qty, case_qty, price = row
        description = description.to_s.strip.gsub(/\s+/, " ")
        amount = MoneyParser.parse(price)

        if upc.to_s == "0"
          totals[description.parameterize.underscore] = amount if %w[Sub-Total Tax Total].include?(description)
          skipped_rows << { line_number: line_number, row: row, reason: "receipt_total_or_payment" }
          next
        end

        if upc.to_s == "-2"
          skipped_rows << { line_number: line_number, row: row, reason: "previous_balance" }
          next
        end

        line_type = description.match?(/coupon/i) || amount&.negative? ? "coupon" : "item"

        line_items << {
          line_number: line_number,
          line_type: line_type,
          raw_sku: upc.to_s.strip.presence,
          raw_name: description,
          raw_quantity: unit_qty.to_s.strip,
          raw_case_quantity: case_qty.to_s.strip,
          raw_price: price.to_s.strip,
          line_total: amount,
          raw_data: {
            source_filename: source_filename,
            csv_line_number: line_number,
            row: row
          }
        }
      end

      {
        source_filename: source_filename,
        store_name: rows.dig(0, 0),
        customer_number: rows.dig(0, 2),
        raw_header: rows.first(header_index),
        receipt_number: invoice_data[:receipt_number],
        terminal: invoice_data[:terminal],
        purchased_at: invoice_data[:purchased_at],
        rows_processed: data_rows.length,
        line_items: line_items,
        totals: totals,
        skipped_rows: skipped_rows,
        errors: errors
      }
    rescue CSV::MalformedCSVError => error
      {
        source_filename: source_filename,
        rows_processed: 0,
        line_items: [],
        totals: {},
        errors: [ error.message ],
        raw_header: []
      }
    end

    private

    def parse_invoice_row(row)
      return {} unless row

      {
        receipt_number: row[0].to_s.sub("Invoice:", "").strip,
        terminal: row[1].to_s.sub("Terminal:", "").strip.presence,
        purchased_at: parse_time(row[2])
      }
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.strptime(value.to_s.strip.upcase, "%Y/%m/%d %I:%M %p")
    rescue ArgumentError
      nil
    end
  end
end
