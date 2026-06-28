require "test_helper"

class ImportBatchesCsvExampleTest < ActionDispatch::IntegrationTest
  test "downloads a receipt csv example from the imports module" do
    get csv_example_import_batches_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment; filename="receipt-import-example\.csv"/, response.headers["Content-Disposition"])
    assert_includes response.body, "UPC,Description,Unit Qty,Case Qty,Price"
    assert_includes response.body, "Invoice: 100001"
  end

  # The example is worthless if it doesn't match what the parser actually accepts.
  # Round-trip the downloaded template through the real parser and assert it finds
  # the item header, parses line items, and reports no errors — i.e. a user who
  # downloads it, fills it in, and uploads it will not hit "Could not find expected
  # receipt item header."
  test "the example is a valid template the receipt parser accepts" do
    get csv_example_import_batches_path

    Tempfile.create([ "receipt-import-example", ".csv" ]) do |file|
      file.write(response.body)
      file.flush

      parsed = Purchasing::ReceiptCsvParser.new.parse(file.path)

      assert_empty parsed[:errors], "example CSV should parse without errors"
      assert_equal "100001", parsed[:receipt_number]
      assert parsed[:line_items].any?, "example CSV should yield at least one line item"
      assert_equal BigDecimal("86.50"), parsed[:totals]["total"]
    end
  end

  test "the upload page links to the csv example with the PWA-safe download pattern" do
    get new_import_batch_path

    # A same-window attachment nav strands an installed PWA on a chrome-less
    # page, so the example link must route through download_controller with a
    # target=_blank no-JS fallback.
    assert_select(
      %(a[href="#{csv_example_import_batches_path}"][data-controller~="download"][data-action~="download#save"][target="_blank"][rel="noopener"][data-download-filename-value="receipt-import-example.csv"]),
      count: 1
    )
  end
end
