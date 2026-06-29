require "test_helper"

# The Review Queue surface card on the home dashboard must agree in number:
# one pending receipt reads "1 receipt to review", not "1 receipts to review".
# The sibling Log Book card already uses pluralize; this card must match so the
# loudest string on the most-emphasized card on the screen stays grammatical.
class HomeDashboardReviewCardTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Review Card Probe Supplier")
    @batch = @supplier.import_batches.create!(
      source_filename: "review-card-probe.csv",
      file_checksum: "review-card-probe-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch, receipt_number: "REVIEW-CARD-PROBE-1", purchased_at: Time.current
    )
  end

  test "a single pending review reads in the singular" do
    build_pending_reviews(1)

    get root_path

    assert_response :success
    assert_review_summary "1 receipt to review"
  end

  test "multiple pending reviews read in the plural" do
    build_pending_reviews(2)

    get root_path

    assert_response :success
    assert_review_summary "2 receipts to review"
  end

  private

  def build_pending_reviews(count)
    count.times do |i|
      line = @receipt.receipt_line_items.create!(
        supplier: @supplier, import_batch: @batch, line_number: i + 1,
        line_type: "item", raw_name: "RAW #{i}", raw_sku: "SKU#{i}",
        row_checksum: SecureRandom.hex(8)
      )
      line.normalization_reviews.create!(
        issue_type: "missing_category", description: "needs review #{i}", status: "pending"
      )
    end
  end

  def assert_review_summary(text)
    assert_select "a[href=?] .home-surface-card-summary", normalization_reviews_path, text: text
  end
end
