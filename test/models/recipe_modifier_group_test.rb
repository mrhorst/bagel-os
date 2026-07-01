require "test_helper"

class RecipeModifierGroupTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:bagel_dough)
    @group = ModifierGroup.create!(name: "Bread")
  end

  test "attaches a group to a recipe" do
    attachment = @recipe.recipe_modifier_groups.create!(modifier_group: @group)
    assert_includes @recipe.reload.modifier_groups, @group
    assert_equal @recipe, attachment.recipe
  end

  test "a group can only be attached to a recipe once" do
    @recipe.recipe_modifier_groups.create!(modifier_group: @group)
    dup = @recipe.recipe_modifier_groups.new(modifier_group: @group)

    assert_not dup.valid?
    assert_includes dup.errors[:modifier_group_id], "has already been taken"
  end

  test "the same group can be shared across recipes" do
    other = recipes(:scallion_spread)
    @recipe.recipe_modifier_groups.create!(modifier_group: @group)
    other.recipe_modifier_groups.create!(modifier_group: @group)

    assert_includes @group.reload.recipes, @recipe
    assert_includes @group.recipes, other
  end

  test "attachments come back in position order" do
    cheese = ModifierGroup.create!(name: "Cheese")
    second = @recipe.recipe_modifier_groups.create!(modifier_group: cheese, position: 2)
    first = @recipe.recipe_modifier_groups.create!(modifier_group: @group, position: 1)

    assert_equal [first, second], @recipe.reload.recipe_modifier_groups.to_a
  end

  test "detaching from a recipe leaves the shared group intact" do
    @recipe.recipe_modifier_groups.create!(modifier_group: @group)

    assert_no_difference "ModifierGroup.count" do
      @recipe.recipe_modifier_groups.destroy_all
    end
    assert ModifierGroup.exists?(@group.id)
  end
end
