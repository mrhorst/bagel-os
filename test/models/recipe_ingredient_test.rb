require "test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:bagel_dough)
    @item = InventoryItem.create!(name: "Flour", key: "flour")
  end

  test "a line linked to an inventory item needs no free-text name" do
    line = @recipe.recipe_ingredients.new(inventory_item: @item, quantity: 5, unit: "lb")
    assert line.valid?
  end

  test "a line with no inventory item requires a name" do
    line = @recipe.recipe_ingredients.new(name: "")
    assert_not line.valid?
    assert_includes line.errors[:name], "can't be blank"
  end

  test "quantity is optional but must be positive when given" do
    assert @recipe.recipe_ingredients.new(name: "Salt").valid?, "blank quantity should be allowed"

    negative = @recipe.recipe_ingredients.new(name: "Salt", quantity: -1)
    assert_not negative.valid?
    assert_includes negative.errors[:quantity], "must be greater than 0"
  end

  test "display_name prefers the linked inventory item name" do
    linked = @recipe.recipe_ingredients.new(inventory_item: @item, name: "ignored override")
    assert_equal "Flour", linked.display_name

    free_text = @recipe.recipe_ingredients.new(name: "Chopped scallions")
    assert_equal "Chopped scallions", free_text.display_name
  end

  test "a recipe can hold multiple ingredient lines" do
    @recipe.recipe_ingredients.create!(inventory_item: @item, quantity: 5, unit: "lb")
    @recipe.recipe_ingredients.create!(name: "Water", quantity: 2, unit: "cup")

    assert_equal 2, @recipe.reload.recipe_ingredients.count
  end
end
