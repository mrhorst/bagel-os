require "test_helper"

class ReceiptCsvParserTest < ActiveSupport::TestCase
  test "parses restaurant depot receipt metadata, lines, totals, and skipped rows" do
    parsed = Purchasing::ReceiptCsvParser.new.parse(
      Rails.root.join("test/fixtures/files/vendor_receipt_sample.csv")
    )

    assert_equal "99999", parsed[:receipt_number]
    assert_equal "12", parsed[:terminal]
    assert_equal 3, parsed[:line_items].size
    assert_equal 9, parsed[:rows_processed]
    assert_equal BigDecimal("68.95"), parsed[:totals]["sub_total"]
    assert_equal "coupon", parsed[:line_items].last[:line_type]
    assert_equal 6, parsed[:skipped_rows].size
    assert_empty parsed[:errors]
  end
end
