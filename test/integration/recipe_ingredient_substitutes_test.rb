require "test_helper"

class RecipeIngredientSubstitutesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @recipe = recipes(:bagel_dough)
    @line = @recipe.recipe_ingredients.create!(name: "Butter", quantity: 2, unit: "oz")
  end

  test "adds a substitute to an ingredient line" do
    assert_difference -> { @line.substitutes.count }, 1 do
      post recipe_ingredient_substitutes_path(@recipe, @line), params: {
        recipe_ingredient_substitute: { name: "Margarine", quantity: "3", unit: "tbsp", note: "1:1 by feel" }
      }
    end

    assert_redirected_to recipe_path(@recipe)
    sub = @line.substitutes.order(:id).last
    assert_equal "Margarine", sub.name
    assert_equal BigDecimal("3"), sub.quantity
    assert_equal "tbsp", sub.unit
  end

  test "the recipe page lists a substitute under its ingredient" do
    @line.substitutes.create!(name: "Margarine")

    get recipe_path(@recipe)
    assert_response :success
    assert_select ".substitute-list", text: /Margarine/
  end

  test "rejecting a substitute with no item and no name re-renders in place keeping input" do
    assert_no_difference -> { @line.substitutes.count } do
      post recipe_ingredient_substitutes_path(@recipe, @line), params: {
        recipe_ingredient_substitute: { inventory_item_id: "", name: "", quantity: "3", unit: "tbsp" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".inline-form-error"
  end

  test "removes a substitute" do
    sub = @line.substitutes.create!(name: "Margarine")

    assert_difference -> { @line.substitutes.count }, -1 do
      delete substitute_path(sub)
    end

    assert_redirected_to recipe_path(@recipe)
  end

  # Regression: the recipe show page reads @weight, so a rejected nested form must
  # still load it. With an existing ingredient on the page, a missing @weight used
  # to crash the in-place re-render.
  test "a rejected substitute re-renders the full recipe without error" do
    @recipe.recipe_ingredients.create!(name: "Flour", quantity: 1, unit: "lb")

    post recipe_ingredient_substitutes_path(@recipe, @line), params: {
      recipe_ingredient_substitute: { name: "", quantity: "1", unit: "tbsp" }
    }

    assert_response :unprocessable_entity
    assert_select ".recipe-cost-summary"
  end
end
