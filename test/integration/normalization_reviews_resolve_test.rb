require "test_helper"

class NormalizationReviewsResolveTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Resolve Confirm Supplier")
    @batch = @supplier.import_batches.create!(
      source_filename: "resolve-confirm.csv",
      file_checksum: "resolve-confirm-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "RESOLVE-CONFIRM-1",
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

  # The review card's sibling actions confirm specifically ("Line item assigned
  # to X.", "Created X."); the resolve/ignore action must do the same so the
  # user can tell which terminal state they applied — not a generic "updated".
  test "resolving a review confirms it was marked resolved" do
    patch resolve_normalization_review_path(@review), params: { review_status: "resolved" }

    assert_response :redirect
    assert_equal "resolved", @review.reload.status
    assert_equal "Review marked resolved.", flash[:notice]
  end

  test "ignoring a review confirms it was marked ignored, not a generic update" do
    patch resolve_normalization_review_path(@review), params: { review_status: "ignored" }

    assert_response :redirect
    assert_equal "ignored", @review.reload.status
    assert_equal "Review marked ignored.", flash[:notice]
    assert_no_match(/updated/i, flash[:notice])
  end
end
