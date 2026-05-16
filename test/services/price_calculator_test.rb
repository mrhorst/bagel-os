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

    assert_equal BigDecimal("2"), calculated[:quantity]
    assert_equal BigDecimal("22.5"), calculated[:package_price]
    assert_equal BigDecimal("50"), calculated[:standard_quantity]
    assert_equal BigDecimal("0.9"), calculated[:standard_unit_price]
  end
end
