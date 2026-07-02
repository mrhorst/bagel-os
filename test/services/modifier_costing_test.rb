require "test_helper"

class ModifierCostingTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Costing Supplier")
    @recipe = Recipe.create!(name: "Test item #{SecureRandom.hex(4)}")
  end

  test "a pick-one group costs its default and reports the swing across options" do
    meat = attach_group("Meat")
    meat.modifier_options.create!(inventory_item: priced_item("Bacon", price: 0.60, unit: "each"),
                                  quantity: 2, unit: "each", default_choice: true, position: 1)
    meat.modifier_options.create!(inventory_item: priced_item("Ham", price: 0.90, unit: "each"),
                                  quantity: 1, unit: "each", position: 2)

    group_cost = Purchasing::ModifierCosting.new(@recipe).groups.sole

    assert group_cost.costed?
    # Standard: the default pick — 2 bacon at $0.60.
    assert_equal BigDecimal("1.20"), group_cost.standard_cost
    # Range: cheapest option (1 ham, $0.90) to priciest (2 bacon, $1.20).
    assert_equal BigDecimal("0.90"), group_cost.min_cost
    assert_equal BigDecimal("1.20"), group_cost.max_cost
  end

  test "a pick-two group counts each figure twice" do
    pair = attach_group("Pick two", min_select: 2, max_select: 2)
    pair.modifier_options.create!(inventory_item: priced_item("Eggs", price: 0.50, unit: "each"),
                                  quantity: 1, unit: "each", default_choice: true, position: 1)
    pair.modifier_options.create!(inventory_item: priced_item("Pancake", price: 0.75, unit: "each"),
                                  quantity: 1, unit: "each", position: 2)

    group_cost = Purchasing::ModifierCosting.new(@recipe).groups.sole

    # The standard configuration takes the default for each of the two picks.
    assert_equal BigDecimal("1.00"), group_cost.standard_cost
    assert_equal BigDecimal("1.00"), group_cost.min_cost
    assert_equal BigDecimal("1.50"), group_cost.max_cost
  end

  test "preparation groups never participate" do
    egg_style = ModifierGroup.create!(name: "Egg style", kind: :preparation)
    egg_style.modifier_options.create!(name: "Over medium", default_choice: true)
    @recipe.recipe_modifier_groups.create!(modifier_group: egg_style)

    costing = Purchasing::ModifierCosting.new(@recipe)

    assert_empty costing.groups
    assert_not costing.complete?
    assert_nil costing.standard_total
  end

  test "one uncostable option makes the whole group uncertain with its reason" do
    bread = attach_group("Bread")
    bread.modifier_options.create!(inventory_item: priced_item("Bagel", price: 0.80, unit: "each"),
                                   quantity: 1, unit: "each", default_choice: true, position: 1)
    # Rye is linked to an unpriced product — no way to bound the range.
    bread.modifier_options.create!(inventory_item: unpriced_item("Rye"), quantity: 1, unit: "each", position: 2)

    group_cost = Purchasing::ModifierCosting.new(@recipe).groups.sole

    assert_not group_cost.costed?
    assert_nil group_cost.standard_cost
    assert_match(/Rye/, group_cost.reason)
    assert_match(/no comparable price/i, group_cost.reason)
  end

  test "a group with no options yet is uncertain" do
    attach_group("Cheese")

    group_cost = Purchasing::ModifierCosting.new(@recipe).groups.sole

    assert_not group_cost.costed?
    assert_match(/no options yet/i, group_cost.reason)
  end

  test "an all-choices item totals from the choices alone" do
    # No fixed ingredient lines — the whole cost lives in the choices, like an
    # eggle. The empty base contributes zero, not uncertainty.
    meat = attach_group("Meat")
    meat.modifier_options.create!(inventory_item: priced_item("Bacon", price: 0.60, unit: "each"),
                                  quantity: 2, unit: "each", default_choice: true, position: 1)
    meat.modifier_options.create!(inventory_item: priced_item("Ham", price: 0.90, unit: "each"),
                                  quantity: 1, unit: "each", position: 2)

    costing = Purchasing::ModifierCosting.new(@recipe)

    assert costing.item_complete?
    assert_equal BigDecimal("1.20"), costing.standard_total
    assert_equal BigDecimal("0.90"), costing.min_total
    assert_equal BigDecimal("1.20"), costing.max_total
  end

  test "base lines and choices combine into the standard total" do
    @recipe.recipe_ingredients.create!(inventory_item: priced_item("Roll", price: 0.50, unit: "each"),
                                       quantity: 1, unit: "each")
    cheese = attach_group("Cheese")
    cheese.modifier_options.create!(inventory_item: priced_item("American", price: 0.30, unit: "each"),
                                    quantity: 1, unit: "each", default_choice: true, position: 1)
    cheese.modifier_options.create!(inventory_item: priced_item("Swiss", price: 0.45, unit: "each"),
                                    quantity: 1, unit: "each", position: 2)

    costing = Purchasing::ModifierCosting.new(@recipe)

    assert_equal BigDecimal("0.80"), costing.standard_total
    assert_equal BigDecimal("0.80"), costing.min_total
    assert_equal BigDecimal("0.95"), costing.max_total
  end

  test "an uncostable base line blocks the combined totals but not the per-group figures" do
    @recipe.recipe_ingredients.create!(name: "Mystery spread", quantity: 1, unit: "tbsp")
    cheese = attach_group("Cheese")
    cheese.modifier_options.create!(inventory_item: priced_item("American", price: 0.30, unit: "each"),
                                    quantity: 1, unit: "each", default_choice: true, position: 1)

    costing = Purchasing::ModifierCosting.new(@recipe)

    assert costing.complete?, "the group itself is costable"
    assert_not costing.item_complete?
    assert_nil costing.standard_total
  end

  test "a group without an explicit default falls back to its first option for the standard" do
    bread = attach_group("Bread")
    bread.modifier_options.create!(inventory_item: priced_item("Bagel", price: 0.80, unit: "each"),
                                   quantity: 1, unit: "each", position: 1)
    bread.modifier_options.create!(inventory_item: priced_item("Kaiser", price: 0.55, unit: "each"),
                                   quantity: 1, unit: "each", position: 2)

    group_cost = Purchasing::ModifierCosting.new(@recipe).groups.sole

    assert_equal BigDecimal("0.80"), group_cost.standard_cost
  end

  private

  def attach_group(name, min_select: 1, max_select: 1)
    group = ModifierGroup.create!(name: name, min_select: min_select, max_select: max_select)
    @recipe.recipe_modifier_groups.create!(modifier_group: group)
    group
  end

  def priced_item(name, price:, unit:)
    item = unpriced_item(name)
    record_observation(item.product, price: price, unit: unit)
    item
  end

  def unpriced_item(name)
    product = @supplier.products.create!(canonical_name: "#{name} #{SecureRandom.hex(4)}")
    InventoryItem.create!(name: "#{name} #{SecureRandom.hex(4)}", key: "#{name.downcase}-#{SecureRandom.hex(4)}", product: product)
  end

  def record_observation(product, price:, unit:)
    batch = @supplier.import_batches.create!(
      source_filename: "costing.csv", file_checksum: SecureRandom.hex(8),
      status: "imported", imported_at: Time.current, rows_processed: 1, rows_imported: 1
    )
    receipt = @supplier.receipts.create!(
      import_batch: batch, receipt_number: "R-#{SecureRandom.hex(4)}",
      purchased_at: Time.current, subtotal: 1, tax: 0, total: 1
    )
    line = receipt.receipt_line_items.create!(
      supplier: @supplier, import_batch: batch, line_number: 1, line_type: "item",
      raw_name: "x", row_checksum: SecureRandom.hex(16)
    )
    PriceObservation.create!(
      product: product, receipt_line_item: line, supplier: @supplier,
      observed_at: Time.current, source_filename: "costing.csv",
      standard_unit_price: price, standard_unit: unit
    )
  end
end
