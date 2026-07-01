require "test_helper"

class RecipeIngredientSubstituteTest < ActiveSupport::TestCase
  setup do
    @recipe = Recipe.create!(name: "Sub recipe #{SecureRandom.hex(4)}")
    @line = @recipe.recipe_ingredients.create!(name: "Butter", quantity: 2, unit: "oz")
  end

  test "needs a name when no inventory item is linked" do
    sub = @line.substitutes.new
    assert_not sub.valid?
    assert_includes sub.errors[:name], "can't be blank"

    assert @line.substitutes.new(name: "Margarine").valid?
  end

  test "its own amount must be positive when given but may be blank" do
    assert @line.substitutes.new(name: "Margarine", quantity: nil).valid?
    assert @line.substitutes.new(name: "Margarine", quantity: 3).valid?

    invalid = @line.substitutes.new(name: "Margarine", quantity: 0)
    assert_not invalid.valid?
  end

  test "effective amount falls back to the parent line when blank" do
    same = @line.substitutes.create!(name: "Margarine")
    assert_equal @line.quantity, same.effective_quantity
    assert_equal @line.unit, same.effective_unit

    own = @line.substitutes.create!(name: "Aquafaba", quantity: 3, unit: "tbsp")
    assert_equal BigDecimal("3"), own.effective_quantity
    assert_equal "tbsp", own.effective_unit
  end

  test "display_name prefers the linked inventory item" do
    item = InventoryItem.create!(name: "Olive oil", key: "olive-#{SecureRandom.hex(4)}")
    linked = @line.substitutes.create!(inventory_item: item)
    assert_equal "Olive oil", linked.display_name

    assert_equal "Margarine", @line.substitutes.create!(name: "Margarine").display_name
  end

  test "substitutes are destroyed with their ingredient" do
    @line.substitutes.create!(name: "Margarine")
    assert_difference -> { RecipeIngredientSubstitute.count }, -1 do
      @line.destroy
    end
  end
end
