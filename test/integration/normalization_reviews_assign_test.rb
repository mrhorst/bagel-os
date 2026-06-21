require "test_helper"

class NormalizationReviewsAssignTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Assign Guard Supplier")
    @category = ProductCategory.create!(name: "Assign Guard Dairy")
    @product = @supplier.products.create!(
      canonical_name: "Whole Milk",
      product_category: @category,
      needs_review: false
    )
    @batch = @supplier.import_batches.create!(
      source_filename: "assign-guard.csv",
      file_checksum: "assign-guard-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "ASSIGN-GUARD-1",
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

  test "assigning with no product selected redirects back with an alert instead of erroring" do
    patch assign_product_normalization_review_path(@review), params: { product_id: "" }

    assert_response :redirect
    assert_equal "Choose a product to assign first.", flash[:alert]
    assert_equal "pending", @review.reload.status
    assert_nil @line_item.reload.product
  end

  test "assigning a real product still resolves the review" do
    patch assign_product_normalization_review_path(@review), params: { product_id: @product.id }

    assert_redirected_to normalization_reviews_path
    assert_equal "resolved", @review.reload.status
    assert_equal @product, @line_item.reload.product
  end
end
