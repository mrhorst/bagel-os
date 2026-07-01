require "test_helper"

class ModifierOptionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @group = ModifierGroup.create!(name: "Meat")
    @bacon = InventoryItem.create!(name: "Bacon", key: "bacon")
  end

  test "adds an option linked to an inventory item" do
    assert_difference -> { @group.modifier_options.count }, 1 do
      post modifier_group_options_path(@group), params: {
        modifier_option: { inventory_item_id: @bacon.id, quantity: "2", unit: "slice", default_choice: "1" }
      }
    end

    # After an add, return to the add form so the next option can be entered
    # without scrolling back past the table.
    assert_redirected_to modifier_group_path(@group, anchor: "add-option")
    option = @group.modifier_options.order(:id).last
    assert_equal @bacon, option.inventory_item
    assert_equal BigDecimal("2"), option.quantity
    assert option.default_choice?
  end

  test "adds a free-text preparation option with no amount" do
    prep = ModifierGroup.create!(name: "Egg style", kind: :preparation)

    post modifier_group_options_path(prep), params: {
      modifier_option: { name: "Over medium", quantity: "", unit: "", default_choice: "1" }
    }

    option = prep.modifier_options.order(:id).last
    assert_nil option.inventory_item
    assert_equal "Over medium", option.name
    # Unknown amount/unit stay blank — never inferred.
    assert_nil option.quantity
    assert option.unit.blank?
  end

  test "rejecting an option with no item and no name re-renders in place keeping input" do
    assert_no_difference -> { @group.modifier_options.count } do
      post modifier_group_options_path(@group), params: {
        modifier_option: { inventory_item_id: "", name: "", quantity: "2", unit: "slice" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".flash-alert"
    # The typed amount/unit survive the failed add.
    assert_select "input[name=?][value=?]", "modifier_option[quantity]", "2"
    assert_select "input[name=?][value=?]", "modifier_option[unit]", "slice"
  end

  test "updates an option in place and returns to its row" do
    option = @group.modifier_options.create!(inventory_item: @bacon, quantity: 2, unit: "slice")

    patch modifier_group_option_path(@group, option), params: {
      modifier_option: { inventory_item_id: @bacon.id, quantity: "3", unit: "slice" }
    }

    assert_redirected_to modifier_group_path(@group, anchor: "option-line-#{option.id}")
    assert_equal BigDecimal("3"), option.reload.quantity
  end

  test "removes an option" do
    option = @group.modifier_options.create!(name: "Ham")

    assert_difference -> { @group.modifier_options.count }, -1 do
      delete modifier_group_option_path(@group, option)
    end

    assert_redirected_to modifier_group_path(@group)
  end

  test "the default option is badged on the show page" do
    @group.modifier_options.create!(inventory_item: @bacon, default_choice: true, position: 1)
    @group.modifier_options.create!(name: "Ham", position: 2)

    get modifier_group_path(@group)
    assert_response :success
    assert_select "td[data-label='Default'] .badge", text: "Default", count: 1
  end
end
