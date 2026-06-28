require "test_helper"

class RecipeCostingTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Costing Supplier")
    @recipe = Recipe.create!(name: "Test recipe #{SecureRandom.hex(4)}")
  end

  test "a fully-costed recipe reports a complete total" do
    @recipe.recipe_ingredients.create!(inventory_item: priced_item("Flour", price: 2, unit: "lb"), quantity: 5, unit: "lb")
    @recipe.recipe_ingredients.create!(inventory_item: priced_item("Eggs", price: 0.25, unit: "each"), quantity: 2, unit: "each")

    costing = Purchasing::RecipeCosting.new(@recipe)

    assert costing.complete?
    # 5 * 2.00 + 2 * 0.25 = 10.50
    assert_equal BigDecimal("10.50"), costing.total
    assert costing.lines.all?(&:costed?)
  end

  test "a recipe with one uncostable line is partial, not complete" do
    @recipe.recipe_ingredients.create!(inventory_item: priced_item("Flour", price: 2, unit: "lb"), quantity: 5, unit: "lb")
    # Free-text line with no inventory item — no price source.
    @recipe.recipe_ingredients.create!(name: "Pinch of malt", quantity: 1, unit: "pinch")

    costing = Purchasing::RecipeCosting.new(@recipe)

    assert_not costing.complete?
    assert_nil costing.total
    assert_equal BigDecimal("10.00"), costing.subtotal
    assert_equal 1, costing.costed_lines.size
    assert_equal 2, costing.total_lines
  end

  test "an entirely uncostable recipe has no subtotal and explains each line" do
    free_text = @recipe.recipe_ingredients.create!(name: "Mystery spice", quantity: 1, unit: "tsp")
    no_price = @recipe.recipe_ingredients.create!(inventory_item: unpriced_item("Salt"), quantity: 1, unit: "lb")

    costing = Purchasing::RecipeCosting.new(@recipe)

    assert_not costing.complete?
    assert_equal 0, costing.costed_lines.size
    assert_equal BigDecimal("0"), costing.subtotal
    assert_match(/not linked to an inventory item/i, costing.cost_for(free_text).reason)
    assert_match(/no comparable price/i, costing.cost_for(no_price).reason)
  end

  test "a unit mismatch is left uncertain rather than converted" do
    item = priced_item("Flour", price: 2, unit: "lb")
    line = @recipe.recipe_ingredients.create!(inventory_item: item, quantity: 1, unit: "cup")

    costing = Purchasing::RecipeCosting.new(@recipe)

    cost = costing.cost_for(line)
    assert_not cost.costed?
    assert_match(/doesn't match the priced unit/i, cost.reason)
  end

  test "plural and singular units are treated as the same unit" do
    item = priced_item("Flour", price: 2, unit: "lb")
    line = @recipe.recipe_ingredients.create!(inventory_item: item, quantity: 3, unit: "lbs")

    costing = Purchasing::RecipeCosting.new(@recipe)

    assert costing.cost_for(line).costed?
    assert_equal BigDecimal("6.00"), costing.cost_for(line).cost
  end

  test "a line with no amount is left uncertain" do
    item = priced_item("Flour", price: 2, unit: "lb")
    line = @recipe.recipe_ingredients.create!(inventory_item: item, unit: "lb")

    cost = Purchasing::RecipeCosting.new(@recipe).cost_for(line)
    assert_not cost.costed?
    assert_match(/no amount/i, cost.reason)
  end

  private

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
