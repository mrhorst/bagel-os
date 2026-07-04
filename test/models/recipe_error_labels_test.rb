require "test_helper"

class RecipeErrorLabelsTest < ActiveSupport::TestCase
  # A failed recipe save must name fields using the words the cook sees on the
  # new/edit form, not the raw column names. app/views/recipes/_form.html.erb
  # labels these inputs "Recipe name" and "Yield amount" — so the validation
  # errors must say the same, or the cook is told to fix a field that isn't on
  # screen (a 0 yield returned "Yield quantity must be greater than 0", and a
  # name collision returned "Name has already been taken"). Mirrors
  # TaskErrorLabelsTest / LogBookSectionTest and the en.yml mapping.
  test "a blank name is named 'Recipe name', not the raw 'Name'" do
    messages = errors_for(Recipe.new(name: ""))

    assert_includes messages, "Recipe name can't be blank"
    refute_leaks messages, ["Name"]
  end

  test "a duplicate name is named 'Recipe name' to match the form" do
    Recipe.create!(name: "Everything bagel dough")
    messages = errors_for(Recipe.new(name: "everything bagel dough"))

    assert_includes messages, "Recipe name has already been taken"
    refute_leaks messages, ["Name"]
  end

  test "a non-positive yield is named 'Yield amount', not the raw 'Yield quantity'" do
    messages = errors_for(Recipe.new(name: "Zero yield", yield_quantity: 0))

    assert_includes messages, "Yield amount must be greater than 0"
    refute_leaks messages, ["Yield quantity"]
  end

  private

  def errors_for(recipe)
    recipe.valid?
    recipe.errors.full_messages
  end

  def refute_leaks(messages, raw_names)
    joined = messages.join(" | ")
    raw_names.each do |raw|
      refute_includes joined, "#{raw} ", "error leaked raw attribute name #{raw.inspect}"
    end
  end
end
