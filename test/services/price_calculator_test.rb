require "test_helper"

class PriceCalculatorTest < ActiveSupport::TestCase
  test "calculates package and standard unit price for reliable unit rows" do
    line = {
      line_type: "item",
      raw_quantity: "2",
      raw_case_quantity: "0",
      line_total: BigDecimal("8.00")
    }
    unit = Purchasing::UnitParser::ParsedUnit.new(
      package_size: BigDecimal("20"),
      unit_of_measure: "oz",
      standard_unit: "oz",
      confidence: 0.95,
      needs_review: false
    )

    calculated = Purchasing::PriceCalculator.new.calculate(line, unit)

    assert_equal BigDecimal("2"), calculated[:unit_quantity]
    assert_equal BigDecimal("0"), calculated[:case_quantity]
    assert_equal "unit", calculated[:purchase_kind]
    assert_equal BigDecimal("2"), calculated[:quantity]
    assert_equal BigDecimal("4.0"), calculated[:package_price]
    assert_equal BigDecimal("40"), calculated[:standard_quantity]
    assert_equal BigDecimal("0.2"), calculated[:standard_unit_price]
    assert_equal "oz", calculated[:standard_unit]
  end

  test "calculates standard unit price for case rows when package size is explicit" do
    line = {
      line_type: "item",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: BigDecimal("48.79")
    }
    unit = Purchasing::UnitParser::ParsedUnit.new(
      package_size: BigDecimal("1"),
      unit_of_measure: "lb",
      standard_unit: "lb",
      confidence: 0.95,
      needs_review: false
    )

    calculated = Purchasing::PriceCalculator.new.calculate(line, unit)

    assert_equal BigDecimal("0"), calculated[:unit_quantity]
    assert_equal BigDecimal("1"), calculated[:case_quantity]
    assert_equal "case", calculated[:purchase_kind]
    assert_equal BigDecimal("48.79"), calculated[:package_price]
    assert_equal BigDecimal("1"), calculated[:standard_quantity]
    assert_equal BigDecimal("48.79"), calculated[:standard_unit_price]
  end

  test "multiplies case quantity by package size for comparable unit price" do
    line = {
      line_type: "item",
      raw_quantity: "0",
      raw_case_quantity: "2",
      line_total: BigDecimal("45.00")
    }
    unit = Purchasing::UnitParser::ParsedUnit.new(
      package_size: BigDecimal("25"),
      unit_of_measure: "lb",
      standard_unit: "lb",
      confidence: 0.9,
      needs_review: false
    )

    calculated = Purchasing::PriceCalculator.new.calculate(line, unit)

    assert_equal BigDecimal("0"), calculated[:unit_quantity]
    assert_equal BigDecimal("2"), calculated[:case_quantity]
    assert_equal "case", calculated[:purchase_kind]
    assert_equal BigDecimal("2"), calculated[:quantity]
    assert_equal BigDecimal("22.5"), calculated[:package_price]
    assert_equal BigDecimal("50"), calculated[:standard_quantity]
    assert_equal BigDecimal("0.9"), calculated[:standard_unit_price]
  end

  test "does not allocate price when unit and case quantities appear on the same row" do
    line = {
      line_type: "item",
      raw_quantity: "1",
      raw_case_quantity: "1",
      line_total: BigDecimal("50.00")
    }
    unit = Purchasing::UnitParser::ParsedUnit.new(
      package_size: BigDecimal("25"),
      unit_of_measure: "lb",
      standard_unit: "lb",
      confidence: 0.9,
      needs_review: false
    )

    calculated = Purchasing::PriceCalculator.new.calculate(line, unit)

    assert_equal BigDecimal("1"), calculated[:unit_quantity]
    assert_equal BigDecimal("1"), calculated[:case_quantity]
    assert_equal "mixed", calculated[:purchase_kind]
    assert_nil calculated[:quantity]
    assert_nil calculated[:package_price]
    assert_nil calculated[:standard_quantity]
    assert_nil calculated[:standard_unit_price]
  end

  test "uses approved case pack facts to calculate inner and comparable unit prices" do
    line = {
      line_type: "item",
      raw_quantity: "0",
      raw_case_quantity: "1",
      line_total: BigDecimal("80.00")
    }
    parsed_unit = Purchasing::UnitParser::ParsedUnit.new(
      package_size: BigDecimal("1"),
      unit_of_measure: "lb",
      standard_unit: "lb",
      confidence: 0.65,
      needs_review: true
    )
    case_pack = SupplierProductPack.new(
      units_per_case: 4,
      inner_unit_label: "pack",
      inner_package_size: 5,
      standard_unit: "lb"
    )

    calculated = Purchasing::PriceCalculator.new.calculate(line, parsed_unit, case_pack: case_pack)

    assert_equal "case", calculated[:purchase_kind]
    assert_equal BigDecimal("80.0"), calculated[:package_price]
    assert_equal BigDecimal("4"), calculated[:inner_quantity]
    assert_equal BigDecimal("20.0"), calculated[:inner_unit_price]
    assert_equal "pack", calculated[:inner_unit_label]
    assert_equal BigDecimal("20"), calculated[:standard_quantity]
    assert_equal BigDecimal("4.0"), calculated[:standard_unit_price]
    assert_equal "lb", calculated[:standard_unit]
    assert_equal "standard_unit", calculated[:price_basis]
  end
end
