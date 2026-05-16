require "test_helper"

class UnitParserTest < ActiveSupport::TestCase
  test "parses clear package units" do
    parsed = Purchasing::UnitParser.new.parse("EGGS XLG LS GRD A  15DZ")

    assert_equal BigDecimal("15"), parsed.package_size
    assert_equal "dozen", parsed.standard_unit
    assert_not parsed.needs_review
  end

  test "does not normalize ambiguous multipack descriptions" do
    parsed = Purchasing::UnitParser.new.parse("PD MUSH SLICED WHT 6-20OZ")

    assert parsed.needs_review
    assert_nil parsed.package_size
    assert_nil parsed.standard_unit
  end

  test "parses case quantities when package size looks like the full purchased presentation" do
    parsed = Purchasing::UnitParser.new.parse("BANANAS 25LB", raw_quantity: "0", raw_case_quantity: "1")

    assert_not parsed.needs_review
    assert_equal BigDecimal("25"), parsed.package_size
    assert_equal "lb", parsed.standard_unit
  end

  test "does not standardize case quantities when package size may be an inner pack" do
    parsed = Purchasing::UnitParser.new.parse("BTR SWT QRTS ST 1LB", raw_quantity: "0", raw_case_quantity: "1")

    assert parsed.needs_review
    assert_equal BigDecimal("1"), parsed.package_size
    assert_equal "lb", parsed.standard_unit
  end

  test "does not treat a five pound case row as the full case weight" do
    parsed = Purchasing::UnitParser.new.parse("CHS AM YL 160SL JF 5LB", raw_quantity: "0", raw_case_quantity: "1")

    assert parsed.needs_review
    assert_equal BigDecimal("5"), parsed.package_size
    assert_equal "lb", parsed.standard_unit
    assert_operator parsed.confidence, :<, BigDecimal("0.9")
  end

  test "flags case quantities when package size is not explicit" do
    parsed = Purchasing::UnitParser.new.parse("UNKNOWN CASE ITEM", raw_quantity: "0", raw_case_quantity: "1")

    assert parsed.needs_review
    assert_nil parsed.package_size
  end
end
