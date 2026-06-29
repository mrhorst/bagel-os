require "test_helper"

class RecipeWeightTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Weight Supplier")
    @recipe = Recipe.create!(name: "Weight recipe #{SecureRandom.hex(4)}")
  end

  test "weighs lines given in weight units and totals them" do
    @recipe.recipe_ingredients.create!(name: "Flour", quantity: 1, unit: "lb")
    @recipe.recipe_ingredients.create!(name: "Sugar", quantity: 100, unit: "g")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert weight.complete?
    # 1 lb (453.59237 g) + 100 g
    assert_in_delta 553.59, weight.total_grams, 0.01
  end

  test "weight needs no price source — a free-text line in grams still counts" do
    line = @recipe.recipe_ingredients.create!(name: "Mystery spice", quantity: 5, unit: "g")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert weight.weight_for(line).weighed?
    assert_equal BigDecimal("5"), weight.total_grams
  end

  test "bridges counted ingredients with an average weight per unit" do
    product = @supplier.products.create!(canonical_name: "Eggs #{SecureRandom.hex(4)}", unit_basis: "count", each_weight_value: 50, each_weight_unit: "g")
    item = InventoryItem.create!(name: "Eggs", key: "eggs-#{SecureRandom.hex(4)}", product: product)
    @recipe.recipe_ingredients.create!(inventory_item: item, quantity: 3, unit: "each")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert weight.complete?
    assert_equal BigDecimal("150.00"), weight.total_grams
  end

  test "a counted line with no average weight is uncertain and explains the fix" do
    product = @supplier.products.create!(canonical_name: "Eggs #{SecureRandom.hex(4)}", unit_basis: "count")
    item = InventoryItem.create!(name: "Eggs", key: "eggs-#{SecureRandom.hex(4)}", product: product)
    line = @recipe.recipe_ingredients.create!(inventory_item: item, quantity: 3, unit: "each")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert_not weight.complete?
    assert_match(/average weight per unit/i, weight.weight_for(line).reason)
  end

  test "a volume line is left out of the total rather than guessed" do
    line = @recipe.recipe_ingredients.create!(name: "Milk", quantity: 1, unit: "cup")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert_not weight.weight_for(line).weighed?
    assert_match(/can't be weighed without a density/i, weight.weight_for(line).reason)
    assert_nil weight.total_grams
  end

  test "weight per serving divides a complete total by the yield" do
    @recipe.update!(yield_quantity: 2, yield_unit: "loaves")
    @recipe.recipe_ingredients.create!(name: "Flour", quantity: 100, unit: "g")

    weight = Purchasing::RecipeWeight.new(@recipe)

    assert_equal BigDecimal("50.00"), weight.weight_per_serving_grams
  end

  test "weight per serving is nil without a yield or a complete total" do
    @recipe.recipe_ingredients.create!(name: "Flour", quantity: 100, unit: "g")
    assert_nil Purchasing::RecipeWeight.new(@recipe).weight_per_serving_grams

    @recipe.update!(yield_quantity: 2, yield_unit: "loaves")
    @recipe.recipe_ingredients.create!(name: "Milk", quantity: 1, unit: "cup")
    assert_nil Purchasing::RecipeWeight.new(@recipe).weight_per_serving_grams
  end
end
