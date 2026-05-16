require "test_helper"

class ImportBatchesShowTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_sample.csv"))
  end

  test "shows receipt header details on import batch page" do
    batch = ImportBatch.find_by!(source_filename: "vendor_receipt_sample.csv")

    get import_batch_path(batch)

    assert_response :success
    assert_select ".page-heading", text: /Wholesale Supplier #1/
    assert_select ".metric span", text: "Receipt date"
    assert_select ".metric strong", text: "2026-05-12 12:39 PM"
    assert_select ".metric span", text: "Receipt number"
    assert_select ".metric strong", text: "99999"
    assert_select ".metric span", text: "Subtotal"
    assert_select ".metric strong", text: "$68.95"
    assert_select ".metric span", text: "Tax paid"
    assert_select ".metric strong", text: "$0.00"
    assert_select ".metric span", text: "Grand total"
    assert_select ".metric strong", text: "$68.95"
    assert_select "th", text: "Unit Qty"
    assert_select "th", text: "Case Qty"
    assert_select "td", text: "unit"
    assert_select "tr[id^='receipt_line_item_']"
  end
end
