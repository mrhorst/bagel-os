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

  test "active and needs_review scopes filter rows" do
    active_reviewed = @supplier.products.create!(canonical_name: "Basil", active: true, needs_review: false)
    inactive = @supplier.products.create!(canonical_name: "Thyme", active: false, needs_review: true)

    assert_includes Product.active, active_reviewed
    assert_not_includes Product.active, inactive
    assert_includes Product.needs_review, inactive
    assert_not_includes Product.needs_review, active_reviewed
  end
end
