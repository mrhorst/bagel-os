require "test_helper"

class NormalizationReviewWorkflowTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb")
    @supplier = Supplier.create!(name: "Test Supplier")
    @category = ProductCategory.find_by!(name: "Dairy")
    @import_batch = @supplier.import_batches.create!(
      source_filename: "review-sample.csv",
      file_checksum: SecureRandom.hex(12),
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @import_batch,
      receipt_number: SecureRandom.hex(6),
      purchased_at: Time.zone.local(2026, 5, 1, 8, 30)
    )
  end

  test "assigning an existing product syncs alias line observation and review state" do
    product = @supplier.products.create!(canonical_name: "Eggs", product_category: @category)
    line_item = create_line_item(raw_name: "EGGS XLG LS GRD A 15DZ")
    review = line_item.normalization_reviews.create!(
      issue_type: "missing_category",
      description: "Needs category review."
    )

    Purchasing::NormalizationReviewWorkflow.new.assign_existing_product(review: review, product: product)

    assert_equal product, line_item.reload.product
    assert_not line_item.needs_review?
    alias_record = product.product_aliases.find_by!(raw_name: line_item.raw_name, raw_sku: line_item.raw_sku)
    assert alias_record.approved?
    assert_equal BigDecimal("1.0"), alias_record.confidence_score
    assert_equal "resolved", review.reload.status
    assert_equal "Assigned to existing product.", review.resolution_notes
    assert_equal product, line_item.price_observation.product
  end

  test "creating a product from review applies conservative product and alias side effects" do
    line_item = create_line_item(raw_name: "TUNA CHUNK LT CQ 66Z", raw_sku: "TUNA123")
    review = line_item.normalization_reviews.create!(
      issue_type: "possible_alias_match",
      description: "Needs product review."
    )

    product = Purchasing::NormalizationReviewWorkflow.new.create_product_from_review(
      review: review,
      canonical_name: "Tuna",
      product_category_id: @category.id
    )

    assert_equal "Tuna", product.canonical_name
    assert_nil product.supplier_sku
    assert_equal @category, product.product_category
    assert_equal product, line_item.reload.product
    assert_not line_item.needs_review?
    assert product.product_aliases.find_by!(raw_name: "TUNA CHUNK LT CQ 66Z", raw_sku: "TUNA123").approved?
    assert_equal "resolved", review.reload.status
    assert_equal product, line_item.price_observation.product
  end

  test "updating review status validates statuses through one workflow" do
    line_item = create_line_item
    review = line_item.normalization_reviews.create!(
      issue_type: "unit_parse",
      description: "Needs unit review."
    )

    Purchasing::NormalizationReviewWorkflow.new.update_review_status(
      review: review,
      status: "ignored",
      notes: "Not worth correcting."
    )

    assert_equal "ignored", review.reload.status
    assert_equal "Not worth correcting.", review.resolution_notes
  end

  test "syncing pending reviews creates intents once and resolves cleared unit reviews" do
    line_item = create_line_item
    workflow = Purchasing::NormalizationReviewWorkflow.new
    unit_intent = Purchasing::ReceiptLineNormalizer::ReviewIntent.new(
      issue_type: "unit_parse",
      description: "Package size or unit needs review."
    )

    workflow.sync_pending_reviews!(line_item: line_item, intents: [ unit_intent ])
    workflow.sync_pending_reviews!(line_item: line_item, intents: [ unit_intent ])

    assert_equal 1, line_item.normalization_reviews.pending.where(issue_type: "unit_parse").count

    workflow.sync_unit_reviews!(line_item: line_item, intents: [])

    review = line_item.normalization_reviews.find_by!(issue_type: "unit_parse")
    assert_equal "resolved", review.status
    assert_equal Purchasing::NormalizationReviewWorkflow::UNIT_PARSE_RESOLVED, review.resolution_notes
  end

  test "syncing unit reviews includes mixed quantity review state" do
    line_item = create_line_item
    workflow = Purchasing::NormalizationReviewWorkflow.new
    mixed_intent = Purchasing::ReceiptLineNormalizer::ReviewIntent.new(
      issue_type: "mixed_quantity",
      description: "Both Unit Qty and Case Qty are present."
    )

    workflow.sync_unit_reviews!(line_item: line_item, intents: [ mixed_intent ])

    review = line_item.normalization_reviews.pending.find_by!(issue_type: "mixed_quantity")
    assert_equal mixed_intent.description, review.description

    workflow.sync_unit_reviews!(line_item: line_item, intents: [])

    assert_equal "resolved", review.reload.status
    assert_equal Purchasing::NormalizationReviewWorkflow::MIXED_QUANTITY_RESOLVED, review.resolution_notes
  end

  private

  def create_line_item(raw_name: "EGGS XLG LS GRD A 15DZ", raw_sku: "SKU123")
    @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @import_batch,
      line_number: ReceiptLineItem.count + 1,
      line_type: "item",
      raw_name: raw_name,
      raw_sku: raw_sku,
      raw_quantity: "1",
      raw_case_quantity: "0",
      raw_unit: "dozen",
      raw_package_description: raw_name,
      quantity: BigDecimal("1"),
      package_price: BigDecimal("30.00"),
      line_total: BigDecimal("30.00"),
      parsed_package_size: BigDecimal("15"),
      parsed_unit_of_measure: "dozen",
      confidence_score: BigDecimal("0.95"),
      needs_review: true,
      row_checksum: SecureRandom.hex(16),
      raw_data: {
        "parsed_unit" => {
          "package_size" => "15",
          "unit_of_measure" => "dozen",
          "standard_unit" => "dozen",
          "confidence" => "0.95",
          "needs_review" => false
        },
        "calculated" => {
          "quantity" => "1",
          "package_price" => "30.0",
          "standard_quantity" => "15",
          "standard_unit_price" => "2.0",
          "standard_unit" => "dozen",
          "price_basis" => "standard_unit"
        }
      }
    )
  end
end
