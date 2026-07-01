require "test_helper"

class ModifierGroupTest < ActiveSupport::TestCase
  test "requires a name" do
    group = ModifierGroup.new(name: "")
    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "name is unique case-insensitively" do
    ModifierGroup.create!(name: "Meat")
    dup = ModifierGroup.new(name: "meat")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "defaults to an ingredient kind with a pick-one rule" do
    group = ModifierGroup.create!(name: "Cheese")
    assert group.ingredient?
    assert_equal 1, group.min_select
    assert_equal 1, group.max_select
  end

  test "can be a preparation kind" do
    group = ModifierGroup.create!(name: "Egg style", kind: :preparation)
    assert group.preparation?
  end

  test "max_select cannot be less than min_select" do
    group = ModifierGroup.new(name: "Two of these", min_select: 2, max_select: 1)
    assert_not group.valid?
    assert_includes group.errors[:max_select], "must be greater than or equal to 2"
  end

  test "selection counts must be positive integers" do
    group = ModifierGroup.new(name: "Bad", min_select: 0)
    assert_not group.valid?
    assert_includes group.errors[:min_select], "must be greater than 0"
  end

  test "default_option prefers the flagged choice" do
    group = ModifierGroup.create!(name: "Bread")
    group.modifier_options.create!(name: "Kaiser", position: 1)
    bagel = group.modifier_options.create!(name: "Bagel", position: 2, default_choice: true)

    assert_equal bagel, group.reload.default_option
  end

  test "default_option falls back to the first option when none is flagged" do
    group = ModifierGroup.create!(name: "Side")
    first = group.modifier_options.create!(name: "Tomato", position: 1)
    group.modifier_options.create!(name: "Home fries", position: 2)

    assert_equal first, group.reload.default_option
  end

  test "selection_summary reads naturally for pick-one, pick-two and ranges" do
    assert_equal "pick 1", ModifierGroup.new(min_select: 1, max_select: 1).selection_summary
    assert_equal "pick 2", ModifierGroup.new(min_select: 2, max_select: 2).selection_summary
    assert_equal "pick 1–2", ModifierGroup.new(min_select: 1, max_select: 2).selection_summary
  end

  test "destroying a group removes its options" do
    group = ModifierGroup.create!(name: "Meat")
    group.modifier_options.create!(name: "Bacon")

    assert_difference "ModifierOption.count", -1 do
      group.destroy
    end
  end
end
