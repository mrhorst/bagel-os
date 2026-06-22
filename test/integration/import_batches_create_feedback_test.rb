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
end
