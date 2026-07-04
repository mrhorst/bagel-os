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

  test "focus mode hides the progress panel when it is the only pending review" do
    # With a single pending review there is nothing to skip to: the controller
    # wraps straight back to the same card (pending.where.not(id:…).first falls
    # back to pending.first), so the Skip button is a no-op whose flash claims
    # the row will "come back around at the end of the queue" when it never
    # left. With Skip gated out, the whole progress panel reduces to an inert
    # "Review 1 of 1" that only repeats the header's "1 open review" count, so
    # it is hidden entirely — same gate the "Show all" link already uses. The
    # review card then sits directly under the page heading.
    get normalization_reviews_path

    assert_select ".review-focus-progress", 0,
      "The progress panel must not render when it is the only pending review — " \
      "with Skip gone it would show only an inert 'Review 1 of 1'."
    assert_select "button", text: "Skip", count: 0,
      message: "Skip must not render when it is the only pending review — it can only re-show the same card."
  end

  test "focus mode offers Skip when more than one review is pending" do
    @line_item.normalization_reviews.create!(
      issue_type: "unit_parse",
      description: "Needs unit review."
    )
    get normalization_reviews_path

    assert_select ".review-focus-progress button", text: "Skip",
      message: "Skip should be available once there is another review to rotate to."
  end
end
