require "application_system_test_case"

# Building a recipe means adding (and tweaking) ingredient lines one after
# another from the form at the BOTTOM of the show page. The ingredient forms
# submit natively rather than via Turbo so the controller's place-preserving
# redirect fragment is honored — otherwise Turbo Drive strips the fragment and
# resets scroll to the top, throwing the user back above the whole table after
# every single add. These tests pin that the browser actually lands back where
# the user was working.
class RecipeIngredientAddScrollTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "adding an ingredient lands back at the add form, not the page top" do
    recipe = recipes(:bagel_dough)
    # Enough existing lines that the "Add ingredient" form sits well below the
    # fold — the situation where being thrown to the page top hurts.
    10.times { |i| recipe.recipe_ingredients.create!(name: "Filler #{i}", position: i) }

    visit recipe_path(recipe)

    within "#add-ingredient" do
      fill_in "Or type a name", with: "Chopped scallions"
      fill_in "Amount", with: "2"
      fill_in "Unit", with: "cup"
      click_on "Add ingredient"
    end

    assert_text "Ingredient added."
    # The URL carries the place-preserving fragment the redirect set…
    assert_equal "add-ingredient", URI(page.current_url).fragment
    # …and the browser actually scrolled the add form into view, so the next
    # line can be typed without scrolling back down.
    assert add_form_in_view?, "expected the Add ingredient form to be in view after an add"
  end

  test "saving an inline edit lands back on the edited row, not the page top" do
    recipe = recipes(:bagel_dough)
    10.times { |i| recipe.recipe_ingredients.create!(name: "Filler #{i}", position: i) }
    edited = recipe.recipe_ingredients.create!(name: "Scallions", quantity: 1, unit: "bunch", position: 99)

    visit recipe_path(recipe)

    within "tr#ingredient-line-#{edited.id}" do
      fill_in "Amount", with: "3"
      click_on "Save"
    end

    assert_text "Ingredient updated."
    assert_equal "ingredient-line-#{edited.id}", URI(page.current_url).fragment
  end

  private

  def add_form_in_view?
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#add-ingredient");
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.top < window.innerHeight && r.bottom > 0;
      })()
    JS
  end
end
