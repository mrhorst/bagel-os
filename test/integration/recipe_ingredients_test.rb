require "test_helper"

class RecipeIngredientsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @recipe = recipes(:bagel_dough)
    @flour = InventoryItem.create!(name: "All-purpose flour", key: "all-purpose-flour")
  end

  test "adds an ingredient linked to an inventory item" do
    assert_difference -> { @recipe.recipe_ingredients.count }, 1 do
      post recipe_ingredients_path(@recipe), params: {
        recipe_ingredient: { inventory_item_id: @flour.id, quantity: "5", unit: "lb" }
      }
    end

    assert_redirected_to recipe_path(@recipe)
    line = @recipe.recipe_ingredients.order(:id).last
    assert_equal @flour, line.inventory_item
    assert_equal BigDecimal("5"), line.quantity
    assert_equal "lb", line.unit

    get recipe_path(@recipe)
    assert_select "td.row-heading", text: /All-purpose flour/
  end

  test "adds a free-text ingredient with an unknown amount and unit left blank" do
    post recipe_ingredients_path(@recipe), params: {
      recipe_ingredient: { name: "Pinch of malt", quantity: "", unit: "" }
    }

    assert_redirected_to recipe_path(@recipe)
    line = @recipe.recipe_ingredients.order(:id).last
    assert_nil line.inventory_item
    assert_equal "Pinch of malt", line.name
    # Unknown amount/unit stay blank — never inferred.
    assert_nil line.quantity
    assert line.unit.blank?
  end

  test "rejecting an ingredient with no item and no name re-renders in place keeping input" do
    assert_no_difference -> { @recipe.recipe_ingredients.count } do
      post recipe_ingredients_path(@recipe), params: {
        recipe_ingredient: { inventory_item_id: "", name: "", quantity: "3", unit: "cup" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".flash-alert"
    # The typed amount/unit survive the failed add.
    assert_select "input[name=?][value=?]", "recipe_ingredient[quantity]", "3"
    assert_select "input[name=?][value=?]", "recipe_ingredient[unit]", "cup"
  end

  test "updates an ingredient line" do
    line = @recipe.recipe_ingredients.create!(inventory_item: @flour, quantity: 5, unit: "lb")

    patch recipe_ingredient_path(@recipe, line), params: {
      recipe_ingredient: { inventory_item_id: @flour.id, quantity: "6", unit: "lb" }
    }

    assert_redirected_to recipe_path(@recipe)
    assert_equal BigDecimal("6"), line.reload.quantity
  end

  test "removes an ingredient line" do
    line = @recipe.recipe_ingredients.create!(name: "Water", quantity: 2, unit: "cup")

    assert_difference -> { @recipe.recipe_ingredients.count }, -1 do
      delete recipe_ingredient_path(@recipe, line)
    end

    assert_redirected_to recipe_path(@recipe)
  end

  test "the recipe show page offers an add-ingredient form" do
    get recipe_path(@recipe)

    assert_response :success
    assert_select "form[action=?]", recipe_ingredients_path(@recipe)
    assert_select "h2", text: "Ingredients"
    assert_select "h2", text: "Add ingredient"
  end
end
