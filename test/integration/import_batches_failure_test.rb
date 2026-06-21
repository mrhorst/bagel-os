require "test_helper"

class ImportBatchesFailureTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    # A CSV without the expected item header fails parser validation, so the
    # batch is recorded with status "failed" and the reason stored in notes.
    Purchasing::CsvImporter.new.import_file(
      Rails.root.join("test/fixtures/files/vendor_receipt_no_header.csv")
    )
  end

  test "surfaces the failure reason and a recovery path on a failed import" do
    batch = ImportBatch.find_by!(source_filename: "vendor_receipt_no_header.csv")
    assert_equal "failed", batch.status
    assert batch.notes.present?, "expected the failed batch to record a reason in notes"

    get import_batch_path(batch)

    assert_response :success
    # The reason the import failed must be visible, not just a "failed" badge.
    assert_select ".flash-alert", text: /This import failed/
    assert_select ".flash-alert", text: /Could not find expected receipt item header/
    # And a clear way to recover from the dead end.
    assert_select ".flash-alert a[href=?]", new_import_batch_path
  end
end
