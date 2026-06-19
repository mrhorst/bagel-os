require "test_helper"

class MoneyParserTest < ActiveSupport::TestCase
  def parse(value)
    Purchasing::MoneyParser.parse(value)
  end

  test "parses currency-formatted positives" do
    assert_equal BigDecimal("12.50"), parse("$12.50")
    assert_equal BigDecimal("1234.56"), parse("1,234.56")
    assert_equal BigDecimal("0"), parse("USD 0")
  end

  test "treats leading minus and parentheses as negative" do
    assert_equal BigDecimal("-3.25"), parse("-3.25")
    assert_equal BigDecimal("-5.00"), parse("(5.00)")
  end

  test "returns nil for blank or non-numeric input" do
    assert_nil parse(nil)
    assert_nil parse("")
    assert_nil parse("   ")
    assert_nil parse("n/a")
  end
end
