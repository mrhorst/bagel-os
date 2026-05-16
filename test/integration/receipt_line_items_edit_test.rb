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
end
