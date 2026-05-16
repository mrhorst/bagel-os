require "test_helper"

class PriceObservationBuilderTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @product = @supplier.products.create!(canonical_name: "Tomatoes")
    @import_batch = @supplier.import_batches.create!(
      source_filename: "demo-receipt.csv",
      file_checksum: "demo-receipt-checksum",
      imported_at: Time.zone.parse("2026-01-01 08:00:00"),
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @import_batch,
      receipt_number: "R-100",
      purchased_at: Time.zone.parse("2026-01-01 09:00:00")
    )
  end

  test "keeps unit and case purchases in separate presentation series" do
    unit_line = create_line_item(line_number: 1, raw_quantity: "1", raw_case_quantity: "0", unit_quantity: 1, case_quantity: 0)
    case_line = create_line_item(line_number: 2, raw_quantity: "0", raw_case_quantity: "1", unit_quantity: 0, case_quantity: 1)

    builder = Purchasing::PriceObservationBuilder.new
    unit_observation = builder.create_for!(unit_line)
    case_observation = builder.create_for!(case_line)

    assert_equal "unit", unit_observation.purchase_kind
    assert_equal "case", case_observation.purchase_kind
    assert_match(/\Aunit\|/, unit_observation.presentation_key)
    assert_match(/\Acase\|/, case_observation.presentation_key)
    assert_not_equal unit_observation.presentation_key, case_observation.presentation_key
  end

  private

  def create_line_item(line_number:, raw_quantity:, raw_case_quantity:, unit_quantity:, case_quantity:)
    @receipt.receipt_line_items.create!(
      supplier: @supplier,
      import_batch: @import_batch,
      product: @product,
      line_number: line_number,
      raw_name: "TOMATOES 25LB",
      raw_sku: "TOM-25",
      raw_quantity: raw_quantity,
      raw_case_quantity: raw_case_quantity,
      unit_quantity: unit_quantity,
      case_quantity: case_quantity,
      quantity: unit_quantity.to_d.positive? ? unit_quantity : case_quantity,
      package_price: 25,
      line_total: 25,
      parsed_package_size: 25,
      parsed_unit_of_measure: "lb",
      confidence_score: 1,
      needs_review: false,
      row_checksum: "row-#{line_number}",
      raw_data: {
        calculated: {
          purchase_kind: unit_quantity.to_d.positive? ? "unit" : "case",
          standard_quantity: 25,
          standard_unit_price: 1
        },
        parsed_unit: {
          standard_unit: "lb",
          confidence: 1
        }
      }
    )
  end
end
