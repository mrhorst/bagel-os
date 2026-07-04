require "test_helper"

class ProductErrorLabelsTest < ActiveSupport::TestCase
  # A failed product save must name fields using the words the reviewer sees on
  # the edit form, not the raw column names. app/views/products/edit.html.erb
  # labels these inputs "Product name", "Average weight per unit", and "Weight
  # unit" — so the validation errors must say the same, or the reviewer is told to
  # fix a field that isn't on screen (a blank name returned "Canonical name can't
  # be blank"; a half-filled weight bridge returned "Each weight unit and the
  # average weight must be filled in together"). Mirrors RecipeErrorLabelsTest /
  # TaskErrorLabelsTest / LogBookSectionTest and the en.yml mapping.
  setup do
    @supplier = Supplier.create!(name: "Probe Supplier")
  end

  test "a blank name is named 'Product name', not the raw 'Canonical name'" do
    messages = errors_for(Product.new(supplier: @supplier, canonical_name: ""))

    assert_includes messages, "Product name can't be blank"
    refute_leaks messages, ["Canonical name"]
  end

  test "a half-filled weight bridge is named 'Weight unit', not the raw 'Each weight unit'" do
    messages = errors_for(Product.new(supplier: @supplier, canonical_name: "Eggs",
                                      each_weight_value: 50, each_weight_unit: ""))

    assert_includes messages, "Weight unit and the average weight must be filled in together"
    refute_leaks messages, ["Each weight unit"]
  end

  test "a non-weight bridge unit is named 'Weight unit', not the raw 'Each weight unit'" do
    messages = errors_for(Product.new(supplier: @supplier, canonical_name: "Eggs",
                                      each_weight_value: 50, each_weight_unit: "cup"))

    assert_includes messages, "Weight unit must be a weight unit (g, kg, oz, lb)"
    refute_leaks messages, ["Each weight unit"]
  end

  test "a non-positive each-weight is named 'Average weight per unit', not the raw 'Each weight value'" do
    messages = errors_for(Product.new(supplier: @supplier, canonical_name: "Eggs",
                                      each_weight_value: 0, each_weight_unit: "g"))

    assert_includes messages, "Average weight per unit must be greater than 0"
    refute_leaks messages, ["Each weight value"]
  end

  private

  def errors_for(product)
    product.valid?
    product.errors.full_messages
  end

  def refute_leaks(messages, raw_names)
    joined = messages.join(" | ")
    raw_names.each do |raw|
      refute_includes joined, "#{raw} ", "error leaked raw attribute name #{raw.inspect}"
    end
  end
end
