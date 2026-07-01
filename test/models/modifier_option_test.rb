require "test_helper"

class ModifierOptionTest < ActiveSupport::TestCase
  setup do
    @group = ModifierGroup.create!(name: "Meat")
    @item = InventoryItem.create!(name: "Bacon", key: "bacon")
  end

  test "an option linked to an inventory item needs no free-text name" do
    option = @group.modifier_options.new(inventory_item: @item, quantity: 2, unit: "slice")
    assert option.valid?
  end

  test "an option with no inventory item requires a name" do
    option = @group.modifier_options.new(name: "")
    assert_not option.valid?
    assert_includes option.errors[:name], "can't be blank"
  end

  test "quantity is optional but must be positive when given" do
    assert @group.modifier_options.new(name: "Over medium").valid?, "blank quantity should be allowed"

    negative = @group.modifier_options.new(name: "Tomato", quantity: -1)
    assert_not negative.valid?
    assert_includes negative.errors[:quantity], "must be greater than 0"
  end

  test "display_name prefers the linked inventory item name" do
    linked = @group.modifier_options.new(inventory_item: @item, name: "ignored override")
    assert_equal "Bacon", linked.display_name

    free_text = @group.modifier_options.new(name: "Over medium")
    assert_equal "Over medium", free_text.display_name
  end

  test "options come back in position order" do
    second = @group.modifier_options.create!(name: "Ham", position: 2)
    first = @group.modifier_options.create!(name: "Bacon", position: 1)

    assert_equal [first, second], @group.reload.modifier_options.to_a
  end
end
