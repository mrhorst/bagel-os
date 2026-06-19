require "test_helper"

# purchase_kind / display_quantity are pure derivations over the quantity
# columns, so they're tested on unsaved instances.
class ReceiptLineItemTest < ActiveSupport::TestCase
  test "purchase_kind classifies by which quantities are present" do
    assert_equal "unit",    ReceiptLineItem.new(unit_quantity: 2, case_quantity: 0).purchase_kind
    assert_equal "case",    ReceiptLineItem.new(unit_quantity: 0, case_quantity: 3).purchase_kind
    assert_equal "mixed",   ReceiptLineItem.new(unit_quantity: 2, case_quantity: 1).purchase_kind
    assert_equal "unknown", ReceiptLineItem.new(unit_quantity: 0, case_quantity: 0).purchase_kind
  end

  test "purchase_kind falls back to raw quantities when normalized ones are nil" do
    assert_equal "unit", ReceiptLineItem.new(raw_quantity: 5).purchase_kind
    assert_equal "case", ReceiptLineItem.new(raw_case_quantity: 4).purchase_kind
  end

  test "display_quantity pluralizes per purchase kind" do
    assert_equal "2 units", ReceiptLineItem.new(unit_quantity: 2).display_quantity
    assert_equal "1 case", ReceiptLineItem.new(case_quantity: 1).display_quantity
    assert_equal "2 units / 1 case", ReceiptLineItem.new(unit_quantity: 2, case_quantity: 1).display_quantity
  end

  test "display_quantity falls back to raw text when nothing is normalized" do
    line = ReceiptLineItem.new(unit_quantity: 0, case_quantity: 0, raw_case_quantity: "see attached")
    assert_equal "see attached", line.display_quantity
  end
end
