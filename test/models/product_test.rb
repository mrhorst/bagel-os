require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup { @supplier = Supplier.primary }

  test "category_name falls back when no category is set" do
    assert_equal "Missing category", Product.new.category_name

    category = ProductCategory.create!(name: "Produce")
    assert_equal "Produce", Product.new(product_category: category).category_name
  end

  test "supplier_sku_summary uses the supplier sku when there are no aliases" do
    with_sku = @supplier.products.create!(canonical_name: "Roma tomato", supplier_sku: "SKU-1")
    without = @supplier.products.create!(canonical_name: "Yellow onion")

    assert_equal "SKU-1", with_sku.supplier_sku_summary
    assert_equal "n/a", without.supplier_sku_summary
  end

  test "canonical_name is required and supplier_sku is unique per supplier" do
    assert_not @supplier.products.new.valid?

    @supplier.products.create!(canonical_name: "Garlic", supplier_sku: "G-1")
    duplicate = @supplier.products.new(canonical_name: "Garlic (peeled)", supplier_sku: "G-1")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:supplier_sku], "has already been taken"
  end

  test "unit_basis only accepts known values and may be blank" do
    assert @supplier.products.new(canonical_name: "Eggs", unit_basis: "count").valid?
    assert @supplier.products.new(canonical_name: "Eggs", unit_basis: nil).valid?

    invalid = @supplier.products.new(canonical_name: "Eggs", unit_basis: "scoops")
    assert_not invalid.valid?
    assert_includes invalid.errors[:unit_basis], "is not included in the list"
  end

  test "count_based?/weight_based? reflect the unit basis" do
    assert @supplier.products.new(unit_basis: "count").count_based?
    assert @supplier.products.new(unit_basis: "weight").weight_based?
    assert_not @supplier.products.new(unit_basis: "count").weight_based?
  end

  test "each_weight bridge must be complete and use a weight unit" do
    only_value = @supplier.products.new(canonical_name: "Eggs", each_weight_value: 50)
    assert_not only_value.valid?
    assert_includes only_value.errors[:each_weight_unit], "and the average weight must be filled in together"

    wrong_dimension = @supplier.products.new(canonical_name: "Eggs", each_weight_value: 50, each_weight_unit: "cup")
    assert_not wrong_dimension.valid?
    assert_includes wrong_dimension.errors[:each_weight_unit], "must be a weight unit (g, kg, oz, lb)"

    valid = @supplier.products.new(canonical_name: "Eggs", each_weight_value: 50, each_weight_unit: "g")
    assert valid.valid?
  end

  test "each_weight_in_grams converts the bridge to grams" do
    product = @supplier.products.new(each_weight_value: 1, each_weight_unit: "oz")
    assert_in_delta 28.349523, product.each_weight_in_grams, 0.0001

    assert_nil @supplier.products.new.each_weight_in_grams
  end

  test "active and needs_review scopes filter rows" do
    active_reviewed = @supplier.products.create!(canonical_name: "Basil", active: true, needs_review: false)
    inactive = @supplier.products.create!(canonical_name: "Thyme", active: false, needs_review: true)

    assert_includes Product.active, active_reviewed
    assert_not_includes Product.active, inactive
    assert_includes Product.needs_review, inactive
    assert_not_includes Product.needs_review, active_reviewed
  end
end
