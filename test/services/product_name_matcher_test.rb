require "test_helper"

class ProductNameMatcherTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @rye_bread = @supplier.products.create!(canonical_name: "Rye Bread")
    @oat_milk = @supplier.products.create!(canonical_name: "Oat Milk")
    @fries = @supplier.products.create!(canonical_name: "Crinkle Cut Fries")
    @sausage_patties = @supplier.products.create!(canonical_name: "Sausage Patties")
    @sausage_links = @supplier.products.create!(canonical_name: "Sausage Links")
  end

  test "matches plain guide wording to conservative product names" do
    matcher = Purchasing::ProductNameMatcher.new

    assert_equal @oat_milk, matcher.match("Oatmilk").product
    assert_equal @fries, matcher.match("Fries").product
  end

  test "does not auto-link ambiguous American cheese guide row" do
    @supplier.products.create!(canonical_name: "American Cheese Yellow")
    @supplier.products.create!(canonical_name: "American Cheese White")
    matcher = Purchasing::ProductNameMatcher.new

    assert_nil matcher.match("American").product
  end

  test "matches sausage formats to separate products" do
    matcher = Purchasing::ProductNameMatcher.new

    assert_equal @sausage_patties, matcher.match("Sausage patties").product
    assert_equal @sausage_links, matcher.match("Sausage Links").product
  end

  test "uses subcategory context for ambiguous bread names" do
    matcher = Purchasing::ProductNameMatcher.new

    match = matcher.match("Rye", context: { subcategory: "Sliced Bread" })

    assert_equal @rye_bread, match.product
    assert_operator match.confidence, :>=, 0.9
  end
end
