require "test_helper"

class RecipesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "lists recipes with a new-recipe affordance" do
    get recipes_path

    assert_response :success
    assert_select "h1", text: "Recipes"
    assert_select "a[href=?]", new_recipe_path
    assert_select "a[href=?]", recipe_path(recipes(:bagel_dough))
  end

  test "creates a recipe and redirects to it" do
    assert_difference -> { Recipe.count }, 1 do
      post recipes_path, params: { recipe: { name: "Everything spice blend", description: "Mix the seeds." } }
    end

    recipe = Recipe.find_by!(name: "Everything spice blend")
    assert_redirected_to recipe_path(recipe)
    assert recipe.active?
  end

  test "create re-renders in place with errors and keeps the typed description" do
    assert_no_difference -> { Recipe.count } do
      post recipes_path, params: { recipe: { name: "", description: "Half-typed method." } }
    end

    assert_response :unprocessable_entity
    assert_select ".flash-alert"
    assert_select "textarea[name=?]", "recipe[description]", text: "Half-typed method."
  end

  test "shows a recipe with its notes" do
    get recipe_path(recipes(:bagel_dough))

    assert_response :success
    assert_select "h1", text: "Plain bagel dough"
    assert_select ".note-block", text: /House bagel dough\./
  end

  test "updates a recipe" do
    recipe = recipes(:bagel_dough)

    patch recipe_path(recipe), params: { recipe: { name: "Sourdough bagel dough", active: "0" } }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal "Sourdough bagel dough", recipe.name
    assert_not recipe.active?
  end

  test "the Stock hub lists Recipes" do
    get stock_hub_path

    assert_response :success
    assert_select "a[href=?]", recipes_path
  end

  test "an employee without the recipes permission is blocked" do
    sign_in_as(users(:two))

    get recipes_path

    assert_response :redirect
  end
end
