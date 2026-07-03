require "test_helper"

class ImportBatchesLineActionsTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    post import_batches_path, params: {
      csv_file: fixture_file_upload("vendor_receipt_sample.csv", "text/csv")
    }
    @batch = ImportBatch.find_by!(source_filename: "vendor_receipt_sample.csv")
  end

  # The import batch is the natural place to triage a freshly imported receipt.
  # Every receipt line must offer a way to open its editor — the per-line surface
  # that resolves review issues and fixes the case pack — the same affordance the
  # product page already provides (products/show.html.erb). Without it a flagged,
  # unassigned line (which appears on no product page) is a dead end.
  test "each receipt line links to its editor so flagged lines aren't a dead end" do
    get import_batch_path(@batch)

    @batch.receipt_line_items.each do |line|
      assert_select "a[href='#{edit_receipt_line_item_path(line, return_to: "import_batch")}']",
        { minimum: 1 },
        "receipt line #{line.line_number} must link to its editor from the import batch"
    end
  end

  # An unassigned line (product nil) never shows on a product page, so the import
  # batch is its only home. It must be reachable, and its action labeled "Review".
  test "an unassigned, needs-review line offers a Review action on the import batch" do
    line = @batch.receipt_line_items.detect { |l| l.product.nil? }
    assert line, "fixture import should produce at least one unassigned line"
    assert line.needs_review?, "the unassigned coupon line should need review"

    get import_batch_path(@batch)

    assert_select "a[href='#{edit_receipt_line_item_path(line, return_to: "import_batch")}']", text: "Review"
  end
end
