require "test_helper"

class ModifierGroupsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "lists modifier groups with their options and usage" do
    bread = ModifierGroup.create!(name: "Bread")
    bread.modifier_options.create!(name: "Bagel", default_choice: true, position: 1)
    bread.modifier_options.create!(name: "Kaiser", position: 2)
    recipes(:bagel_dough).recipe_modifier_groups.create!(modifier_group: bread)

    get modifier_groups_path
    assert_response :success
    assert_select "td.row-heading", text: /Bread/
    assert_select "td[data-label='Options']", text: /Bagel or Kaiser/
    assert_select "td[data-label='Used by']", text: /1 recipe/
  end

  test "creates an ingredient modifier with a pick-one rule" do
    assert_difference "ModifierGroup.count", 1 do
      post modifier_groups_path, params: {
        modifier_group: { name: "Cheese", kind: "ingredient", min_select: 1, max_select: 1 }
      }
    end

    group = ModifierGroup.order(:id).last
    assert_redirected_to modifier_group_path(group)
    assert group.ingredient?
  end

  test "creates a pick-two preparation-free choice like a 2-2-2" do
    post modifier_groups_path, params: {
      modifier_group: { name: "Pick two", kind: "ingredient", min_select: 2, max_select: 2 }
    }

    group = ModifierGroup.order(:id).last
    assert_equal 2, group.min_select
    assert_equal 2, group.max_select
    assert_equal "pick 2", group.selection_summary
  end

  test "rejects a max below the min and re-renders the form" do
    assert_no_difference "ModifierGroup.count" do
      post modifier_groups_path, params: {
        modifier_group: { name: "Broken", min_select: 2, max_select: 1 }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".flash-alert"
  end

  test "updates a group" do
    group = ModifierGroup.create!(name: "Egg style")

    patch modifier_group_path(group), params: { modifier_group: { kind: "preparation" } }

    assert_redirected_to modifier_group_path(group)
    assert group.reload.preparation?
  end

  test "deleting a group detaches it from recipes without touching them" do
    group = ModifierGroup.create!(name: "Sides")
    group.modifier_options.create!(name: "Home fries")
    recipes(:bagel_dough).recipe_modifier_groups.create!(modifier_group: group)

    assert_difference [ "ModifierGroup.count", "ModifierOption.count", "RecipeModifierGroup.count" ], -1 do
      delete modifier_group_path(group)
    end

    assert_redirected_to modifier_groups_path
    assert Recipe.exists?(recipes(:bagel_dough).id)
  end

  test "the show page explains ingredient vs preparation options" do
    ingredient_group = ModifierGroup.create!(name: "Meat")
    get modifier_group_path(ingredient_group)
    assert_response :success
    assert_select "p.muted", text: /count toward cost/

    prep_group = ModifierGroup.create!(name: "Egg style", kind: :preparation)
    get modifier_group_path(prep_group)
    assert_select "p.muted", text: /tells the kitchen/
  end
end
