require "test_helper"

class NormalizationReviewsSkipTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Skip Feedback Supplier")
    @batch = @supplier.import_batches.create!(
      source_filename: "skip-feedback.csv",
      file_checksum: "skip-feedback-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "SKIP-FEEDBACK-1",
      purchased_at: Time.current
    )
    @line_item = @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @batch,
      line_number: 1,
      line_type: "item",
      raw_name: "MLK WHL 4/1GAL",
      raw_sku: "MILK-CASE",
      row_checksum: SecureRandom.hex(8)
    )
    @review = @line_item.normalization_reviews.create!(
      issue_type: "missing_category",
      description: "Needs category review."
    )
  end

  test "skipping a review confirms the action with a flash notice" do
    patch skip_normalization_review_path(@review)

    assert_redirected_to normalization_reviews_path
    assert flash[:notice].present?,
      "Skip should confirm the action with a flash notice, like every other review action — " \
      "otherwise the page reloads (the same card, when it's the only pending review) with no feedback."
    assert_equal "pending", @review.reload.status
  end
end
