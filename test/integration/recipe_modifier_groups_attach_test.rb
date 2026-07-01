require "test_helper"

class RecipeModifierGroupsAttachTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @recipe = recipes(:bagel_dough)
    @bread = ModifierGroup.create!(name: "Bread")
    @bread.modifier_options.create!(name: "Bagel", default_choice: true, position: 1)
    @bread.modifier_options.create!(name: "Kaiser", position: 2)
  end

  test "attaches a modifier to a recipe" do
    assert_difference -> { @recipe.recipe_modifier_groups.count }, 1 do
      post recipe_modifiers_path(@recipe), params: {
        recipe_modifier_group: { modifier_group_id: @bread.id }
      }
    end

    assert_redirected_to recipe_path(@recipe, anchor: "modifiers")
    assert_includes @recipe.reload.modifier_groups, @bread
  end

  test "an empty attach select is rejected with a plain message" do
    assert_no_difference -> { @recipe.recipe_modifier_groups.count } do
      post recipe_modifiers_path(@recipe), params: {
        recipe_modifier_group: { modifier_group_id: "" }
      }
    end

    assert_redirected_to recipe_path(@recipe, anchor: "modifiers")
    assert_equal "Choose a modifier to attach.", flash[:alert]
  end

  test "detaches a modifier without touching the shared group" do
    attachment = @recipe.recipe_modifier_groups.create!(modifier_group: @bread)

    assert_no_difference [ "ModifierGroup.count", "ModifierOption.count" ] do
      assert_difference -> { @recipe.recipe_modifier_groups.count }, -1 do
        delete recipe_modifier_path(@recipe, attachment)
      end
    end

    assert_redirected_to recipe_path(@recipe, anchor: "modifiers")
  end

  test "the recipe page lists attached choices with the default marked" do
    @recipe.recipe_modifier_groups.create!(modifier_group: @bread)

    get recipe_path(@recipe)
    assert_response :success
    assert_select "#modifiers td.row-heading", text: /Bread/
    assert_select "#modifiers td[data-label='Options']", text: /Bagel \(default\) or Kaiser/
  end

  test "the attach select offers only groups not already attached" do
    cheese = ModifierGroup.create!(name: "Cheese")
    @recipe.recipe_modifier_groups.create!(modifier_group: @bread)

    get recipe_path(@recipe)
    assert_select "#modifiers select option", text: "Cheese"
    assert_select "#modifiers select option", text: "Bread", count: 0

    # With everything attached, the form gives way to a pointer at the library.
    @recipe.recipe_modifier_groups.create!(modifier_group: cheese)
    get recipe_path(@recipe)
    assert_select "#modifiers select", count: 0
    assert_select "#modifiers p", text: /already attached/
  end
end
