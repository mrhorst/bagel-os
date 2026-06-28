require "test_helper"

class ReceiptLineItemsEditTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Line Edit Supplier")
    category = ProductCategory.create!(name: "Dairy")
    @product = @supplier.products.create!(
      canonical_name: "American Cheese Yellow",
      product_category: category,
      needs_review: false
    )
    @batch = @supplier.import_batches.create!(
      source_filename: "receipt-line-edit.csv",
      file_checksum: "receipt-line-edit-#{SecureRandom.hex(8)}",
      imported_at: Time.zone.local(2026, 5, 1, 12),
      status: "imported",
      rows_processed: 1,
      rows_imported: 1
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch,
      receipt_number: "LINE-EDIT-1",
      purchased_at: Time.zone.local(2026, 5, 1, 12),
      subtotal: 47.78,
      tax: 0,
      total: 47.78
    )
    @line_item = @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @batch,
      product: @product,
      line_number: 1,
      line_type: "item",
      raw_name: "CHS AM YL 160SL JF 5LB",
      raw_sku: "CHEESE-CASE",
      raw_quantity: "0",
      raw_case_quantity: "1",
      unit_quantity: 0,
      case_quantity: 1,
      quantity: 1,
      line_total: 47.78,
      package_price: 47.78,
      parsed_package_size: 5,
      parsed_unit_of_measure: "lb",
      confidence_score: 0.65,
      needs_review: true,
      row_checksum: SecureRandom.hex(16),
      raw_data: {
        "parsed_unit" => {
          "package_size" => "5",
          "unit_of_measure" => "lb",
          "standard_unit" => "lb",
          "confidence" => "0.65",
          "needs_review" => true
        },
        "calculated" => {
          "purchase_kind" => "case"
        }
      }
    )
    @line_item.normalization_reviews.create!(
      product: @product,
      issue_type: "case_pack",
      description: "Case quantity is present.",
      status: "pending"
    )
    Purchasing::PriceObservationBuilder.new.create_for!(@line_item)
  end

  test "edits a case-pack fact for one receipt line and recalculates its observation" do
    get edit_receipt_line_item_path(@line_item)

    assert_response :success
    assert_select "h1", text: "Edit purchase line"
    assert_select "input[name='supplier_product_pack[units_per_case]']"
    assert_select "input[name='supplier_product_pack[inner_package_size]'][value='5.0']"

    patch receipt_line_item_path(@line_item), params: {
      supplier_product_pack: {
        units_per_case: "4",
        inner_unit_label: "pack",
        inner_package_size: "5",
        inner_unit_of_measure: "lb",
        standard_unit: "lb",
        notes: "Verified from case label"
      }
    }

    assert_redirected_to product_path(@product, anchor: "receipt_line_item_#{@line_item.id}")

    @line_item.reload
    observation = @line_item.price_observation.reload
    fact = @line_item.case_pack

    assert_equal BigDecimal("4"), fact.units_per_case
    assert_equal "pack", fact.inner_unit_label
    assert_equal BigDecimal("5"), fact.inner_package_size
    assert fact.approved?
    assert_equal "receipt line edit", fact.source_label
    assert_equal BigDecimal("4"), @line_item.inner_quantity
    assert_equal BigDecimal("11.945"), @line_item.inner_unit_price
    assert_equal BigDecimal("20"), observation.standard_quantity
    assert_equal BigDecimal("2.389"), observation.standard_unit_price
    assert_not @line_item.needs_review?
    assert_equal "resolved", @line_item.normalization_reviews.find_by!(issue_type: "case_pack").status
  end

  test "edits a case-pack fact and recalculates other matching case receipt lines" do
    matching_case_line = create_receipt_line!(
      receipt_number: "LINE-EDIT-2",
      source_filename: "receipt-line-edit-2.csv",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: 67.42,
      needs_review: true
    )
    matching_case_line.normalization_reviews.create!(
      product: @product,
      issue_type: "case_pack",
      description: "Case quantity is present.",
      status: "pending"
    )
    unit_line = create_receipt_line!(
      receipt_number: "LINE-EDIT-3",
      source_filename: "receipt-line-edit-3.csv",
      raw_quantity: "1",
      raw_case_quantity: "0",
      line_total: 11.88,
      needs_review: true
    )

    patch receipt_line_item_path(@line_item), params: {
      supplier_product_pack: {
        units_per_case: "4",
        inner_unit_label: "pack",
        inner_package_size: "5",
        inner_unit_of_measure: "lb",
        standard_unit: "lb",
        notes: "Verified from case label"
      }
    }

    assert_redirected_to product_path(@product, anchor: "receipt_line_item_#{@line_item.id}")

    fact = @line_item.reload.case_pack
    matching_case_line.reload
    unit_line.reload

    assert_equal fact, matching_case_line.case_pack
    assert_equal BigDecimal("4"), matching_case_line.inner_quantity
    assert_equal BigDecimal("16.855"), matching_case_line.inner_unit_price
    assert_not matching_case_line.needs_review?
    assert_equal "resolved", matching_case_line.normalization_reviews.find_by!(issue_type: "case_pack").status
    assert_nil unit_line.case_pack
    assert_nil unit_line.inner_quantity
    assert unit_line.needs_review?
  end

  test "a unit line flagged for price can be resolved from the edit page (no dead-end)" do
    # A unit-kind line flagged for review but carrying a price review (the kind
    # the importer now emits, #172) must show the resolve UI — not the
    # contradictory "No pending review issues" note with no way to clear it.
    line = create_receipt_line!(
      receipt_number: "PRICE-FLAG-1",
      source_filename: "price-flag-1.csv",
      raw_quantity: "1",
      raw_case_quantity: "0",
      line_total: 0,
      needs_review: true
    )
    review = line.normalization_reviews.create!(
      product: @product,
      issue_type: "price",
      description: Purchasing::ReceiptLineNormalizer::PRICE_REVIEW,
      status: "pending"
    )

    get edit_receipt_line_item_path(line)
    assert_response :success
    assert_select ".review-decision-list h3", text: "Review this line"
    assert_select ".resolved-note", text: /No pending review issues/, count: 0

    patch resolve_normalization_review_path(review), params: {
      review_status: "resolved",
      resolution_notes: "Verified from receipt line edit."
    }

    assert_equal "resolved", review.reload.status
    assert_not line.reload.needs_review?
  end

  private

  def create_receipt_line!(receipt_number:, source_filename:, raw_quantity:, raw_case_quantity:, line_total:, needs_review:)
    batch = @supplier.import_batches.create!(
      source_filename: source_filename,
      file_checksum: "#{source_filename}-#{SecureRandom.hex(8)}",
      imported_at: Time.zone.local(2026, 5, 2, 12),
      status: "imported",
      rows_processed: 1,
      rows_imported: 1
    )
    receipt = @supplier.receipts.create!(
      import_batch: batch,
      receipt_number: receipt_number,
      purchased_at: Time.zone.local(2026, 5, 2, 12),
      subtotal: line_total,
      tax: 0,
      total: line_total
    )
    receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: batch,
      product: @product,
      line_number: 1,
      line_type: "item",
      raw_name: "CHS AM YL 160SL JF 5LB",
      raw_sku: "CHEESE-CASE",
      raw_quantity: raw_quantity,
      raw_case_quantity: raw_case_quantity,
      unit_quantity: raw_quantity.to_d,
      case_quantity: raw_case_quantity.to_d,
      quantity: raw_quantity.to_d.positive? ? raw_quantity.to_d : raw_case_quantity.to_d,
      line_total: line_total,
      package_price: line_total,
      parsed_package_size: 5,
      parsed_unit_of_measure: "lb",
      confidence_score: 0.65,
      needs_review: needs_review,
      row_checksum: SecureRandom.hex(16),
      raw_data: {
        "parsed_unit" => {
          "package_size" => "5",
          "unit_of_measure" => "lb",
          "standard_unit" => "lb",
          "confidence" => "0.65",
          "needs_review" => true
        },
        "calculated" => {
          "purchase_kind" => raw_case_quantity.to_d.positive? ? "case" : "unit"
        }
      }
    )
  end
end
