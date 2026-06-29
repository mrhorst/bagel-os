require "test_helper"

class ImportBatchesBinaryUploadTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
  end

  # The importer goes to great lengths to report a bad upload as a recoverable
  # FAILED batch (malformed CSV, missing header, missing receipt number, …) — but
  # one class of file slipped through: when the upload's leading bytes are a
  # UTF-16/UTF-32 byte-order mark, CSV.read honors the BOM and decodes as UTF-16;
  # if the rest of the file isn't valid UTF-16 (a corrupted/truncated "Unicode
  # Text" export, or a binary file that happens to start with those bytes) it
  # raises Encoding::InvalidByteSequenceError. That escapes the parser's
  # CSV::MalformedCSVError rescue, the importer's RecordInvalid rescue, and the
  # controller — crashing the upload to a 500 with no reason and no way back,
  # instead of the recoverable failed-batch every other bad file produces.
  test "a non-decodable upload is reported as a recoverable failure, not a 500" do
    assert_nothing_raised do
      post import_batches_path, params: {
        csv_file: fixture_file_upload("corrupt_unicode_export.csv", "text/csv")
      }
    end

    batch = ImportBatch.find_by!(source_filename: "corrupt_unicode_export.csv")
    assert_equal "failed", batch.status
    assert batch.notes.present?, "expected the failed batch to record a reason in notes"

    assert flash[:alert].present?, "a failed import must surface a danger flash"
    assert_nil flash[:notice], "a non-decodable upload must not be reported as a success"
    assert_redirected_to import_batch_path(batch)
  end

  test "the failed import shows a plain-language reason and a recovery path" do
    post import_batches_path, params: {
      csv_file: fixture_file_upload("corrupt_unicode_export.csv", "text/csv")
    }
    batch = ImportBatch.find_by!(source_filename: "corrupt_unicode_export.csv")

    get import_batch_path(batch)

    assert_response :success
    assert_select ".flash-alert", text: /This import failed/
    # The reason must be a readable hint, not a raw "invalid byte sequence" dump.
    assert_select ".flash-alert", text: /couldn't be read as a CSV/
    assert_select ".flash-alert a[href=?]", new_import_batch_path
  end
end
