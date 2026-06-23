require "test_helper"

class ImportBatchesIndexTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_sample.csv"))
  end

  # A batch can finish "imported" yet still leave lines flagged for review. The
  # post-import flash is the only transient cue; once it's gone the index must
  # still show the pending count, or an unfinished import looks done.
  test "imports index surfaces the per-batch needs-review count" do
    batch = ImportBatch.find_by!(source_filename: "vendor_receipt_sample.csv")
    review_count = batch.receipt_line_items.needs_review.count
    assert review_count.positive?,
      "fixture must produce at least one line needing review for this test to be meaningful"

    get import_batches_path

    assert_response :success
    assert_select "th", text: "Needs review"
    assert_select "td[data-label='Needs review']", text: review_count.to_s
  end
end
