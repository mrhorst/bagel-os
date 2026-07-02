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

    # Land back on the annotated line, not the page top, so building out a line's
    # substitutes on a long recipe doesn't bounce the reader up every time.
    assert_redirected_to recipe_path(@recipe, anchor: "ingredient-line-#{@line.id}")
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

  test "the add-substitute form submits natively so its place-preserving anchor lands" do
    # The success redirect carries a #ingredient-line-N fragment; Turbo Drive
    # would strip that fragment and reset scroll to the top. A native submit
    # (data-turbo=false) is what lets the browser honor the fragment — mirroring
    # the ingredient add/edit forms. Guard the attribute so a Turbo regression is
    # caught here rather than as a silent jump-to-top in the browser.
    get recipe_path(@recipe)
    assert_response :success
    assert_select "form.inline-ingredient-form[action=?][data-turbo='false']",
      recipe_ingredient_substitutes_path(@recipe, @line)
  end

  test "rejecting a substitute with no item and no name re-renders in place keeping input" do
    assert_no_difference -> { @line.substitutes.count } do
      post recipe_ingredient_substitutes_path(@recipe, @line), params: {
        recipe_ingredient_substitute: { inventory_item_id: "", name: "", quantity: "3", unit: "tbsp" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".inline-form-error"
    # The native submit lands the browser at the page top; the re-render wires the
    # scroll-into-view controller onto the annotated row so the rejected
    # substitute's error is pulled into view instead of stranded below the fold.
    assert_select "tr#ingredient-line-#{@line.id}[data-controller=?]", "scroll-into-view"
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
