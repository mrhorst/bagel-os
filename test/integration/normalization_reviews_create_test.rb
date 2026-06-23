require "test_helper"

# Guards the "Or create new" action on a Review Queue card. A receipt line is
# often flagged for a quantity/category issue while its SKU already belongs to a
# product the supplier created on an earlier receipt. Clicking "Create new" then
# hits the supplier_sku uniqueness validation; an unguarded create! used to bubble
# up as a static 422 dead-end, losing the user's input and their place in the
# queue. It should instead redirect back with an explanatory alert, the same way
# the sibling "Assign to existing product" action does.
class NormalizationReviewsCreateTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Create Guard Supplier")
    @category = ProductCategory.create!(name: "Create Guard Dairy")
    # An existing product for this supplier already owns the SKU.
    @existing = @supplier.products.create!(
      canonical_name: "Whole Milk",
      supplier_sku: "MILK-CASE",
      product_category: @category,
      needs_review: false
    )
    @batch = @supplier.import_batches.create!(
      source_filename: "create-guard.csv",
      file_checksum: "create-guard-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "CREATE-GUARD-1",
      purchased_at: Time.current
    )
    # A later line carrying the SAME raw_sku, flagged for review.
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

  test "creating a product whose SKU collides redirects back with an alert instead of a 422 dead-end" do
    assert_no_difference -> { Product.count } do
      patch create_product_normalization_review_path(@review),
        params: { canonical_name: "Whole Milk Again", product_category_id: @category.id }
    end

    assert_response :redirect
    assert_match(/Couldn't create product/, flash[:alert])
    assert_equal "pending", @review.reload.status
    assert_nil @line_item.reload.product
  end

  test "creating a product with a free SKU still resolves the review" do
    @line_item.update!(raw_sku: "MILK-NEW")

    assert_difference -> { Product.count }, 1 do
      patch create_product_normalization_review_path(@review),
        params: { canonical_name: "Skim Milk", product_category_id: @category.id }
    end

    assert_redirected_to normalization_reviews_path
    assert_equal "resolved", @review.reload.status
    assert_equal "Skim Milk", @line_item.reload.product.canonical_name
  end
end
