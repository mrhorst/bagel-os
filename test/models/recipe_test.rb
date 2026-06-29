require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "requires a name" do
    recipe = Recipe.new(name: "")
    assert_not recipe.valid?
    assert_includes recipe.errors[:name], "can't be blank"
  end

  test "name is unique case-insensitively" do
    Recipe.create!(name: "Bagel Dough")
    dup = Recipe.new(name: "bagel dough")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "active scope returns only active recipes" do
    active = Recipe.create!(name: "Active one", active: true)
    Recipe.create!(name: "Archived one", active: false)

    assert_includes Recipe.active, active
    assert_equal Recipe.active.to_a, Recipe.where(active: true).to_a
  end

  test "ordered sorts by position then name" do
    Recipe.delete_all
    second = Recipe.create!(name: "Apple", position: 2)
    first = Recipe.create!(name: "Zucchini", position: 1)

    assert_equal [ first, second ], Recipe.ordered.to_a
  end

  test "archived? mirrors inactive state" do
    assert Recipe.new(active: false).archived?
    assert_not Recipe.new(active: true).archived?
  end

  test "yield_quantity must be positive when given and may be blank" do
    assert Recipe.new(name: "Yield ok", yield_quantity: 12).valid?
    assert Recipe.new(name: "Yield blank", yield_quantity: nil).valid?

    invalid = Recipe.new(name: "Yield bad", yield_quantity: 0)
    assert_not invalid.valid?
    assert_includes invalid.errors[:yield_quantity], "must be greater than 0"
  end

  test "yield_described? reflects a positive yield" do
    assert Recipe.new(yield_quantity: 12).yield_described?
    assert_not Recipe.new(yield_quantity: nil).yield_described?
  end
end
