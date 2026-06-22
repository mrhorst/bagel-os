require "test_helper"

class ImportBatchesCreateFeedbackTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
  end

  # A CSV missing the expected item header fails parser validation. The upload
  # must be reported as a FAILURE (danger flash), not a success (notice), and
  # must land the user on the batch where the reason + recovery path live.
  test "a failed upload is reported as an alert, not a success notice" do
    post import_batches_path, params: {
      csv_file: fixture_file_upload("vendor_receipt_no_header.csv", "text/csv")
    }

    batch = ImportBatch.find_by!(source_filename: "vendor_receipt_no_header.csv")
    assert_equal "failed", batch.status

    assert flash[:alert].present?, "a failed import must surface a danger flash"
    assert_nil flash[:notice], "a failed import must not be reported as a success notice"
    assert_redirected_to import_batch_path(batch)
  end

  # A clean upload stays a success notice on the imports index.
  test "a successful upload is reported as a success notice" do
    post import_batches_path, params: {
      csv_file: fixture_file_upload("vendor_receipt_sample.csv", "text/csv")
    }

    assert flash[:notice].present?, "a successful import must surface a notice"
    assert_nil flash[:alert], "a successful import must not surface a danger flash"
    assert_redirected_to import_batches_path
  end

  # The whole point of importing is the review queue it feeds. The success notice
  # is the only cue before the user lands on the index (no review column there),
  # so when lines couldn't be matched confidently it must say how many need
  # review — otherwise the import looks finished when it isn't.
  test "the success notice reports how many lines need review" do
    post import_batches_path, params: {
      csv_file: fixture_file_upload("vendor_receipt_sample.csv", "text/csv")
    }

    batch = ImportBatch.find_by!(source_filename: "vendor_receipt_sample.csv")
    review_count = batch.receipt_line_items.needs_review.count
    assert review_count.positive?,
      "fixture must produce at least one line needing review for this test to be meaningful"

    assert_match(/#{review_count}\s+#{review_count == 1 ? "line needs" : "lines need"} review/, flash[:notice],
      "the success notice should tell the user how many lines need review")
  end
end
