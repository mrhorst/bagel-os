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
    assert_selector "#add-ingredient"

    within "#add-ingredient" do
      fill_in "Or type a name", with: "Chopped scallions"
      fill_in "Amount", with: "2"
      fill_in "Unit", with: "cup"
    end
    submit_form "#add-ingredient form"

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
    assert_selector "tr#ingredient-line-#{edited.id}"

    within "tr#ingredient-line-#{edited.id}" do
      fill_in "Amount", with: "3"
    end
    submit_form "form[action='#{recipe_ingredient_path(recipe, edited)}']"

    assert_text "Ingredient updated."
    assert_equal "ingredient-line-#{edited.id}", URI(page.current_url).fragment
  end

  # The failure counterpart to the two success tests above: a rejected submit
  # re-renders the page in place (keeping input + error) but, being a native
  # submit with no place-preserving redirect fragment, lands the browser at the
  # page TOP. Without a nudge the error sits below the fold on a long recipe and
  # the submit reads as a silent no-op. The scroll-into-view controller pulls the
  # errored form/row back into view.
  test "a rejected add scrolls the error into view instead of stranding it at the top" do
    recipe = recipes(:bagel_dough)
    10.times { |i| recipe.recipe_ingredients.create!(name: "Filler #{i}", position: i) }

    visit recipe_path(recipe)
    assert_selector "#add-ingredient" # gate on the page being loaded before typing

    # Fill inside the add form (Amount/Unit repeat on every row), but let the
    # `within` scope close before submitting.
    within "#add-ingredient" do
      # Amount + unit but no name and no inventory item -> "Name can't be blank".
      fill_in "Amount", with: "2"
      fill_in "Unit", with: "cup"
    end
    # Submit the form directly rather than clicking: headless Chrome intermittently
    # drops the submit click here (see the dropped-click notes in
    # ApplicationSystemTestCase), and a native submit gives Capybara nothing to
    # wait on, so a lost click would flake. requestSubmit is deterministic and,
    # because the form is data-turbo=false, still performs the real native
    # navigation whose re-render this test is about.
    submit_form "#add-ingredient form"

    # The rejected line re-renders in place with its error…
    assert_text "Name can't be blank"
    # …and the add form (which holds that error) was scrolled back into view,
    # rather than left at the bottom while the browser sits at the page top.
    assert add_form_in_view?, "expected the rejected Add ingredient form to be scrolled into view"
    assert page.evaluate_script("window.pageYOffset") > 0,
      "expected the page to be scrolled down to the errored form, not left at the top"
  end

  test "a rejected inline edit scrolls the errored row into view" do
    recipe = recipes(:bagel_dough)
    # Fillers first so the edited row sits well below the fold — where landing at
    # the page top after a rejected edit would hide the error.
    10.times { |i| recipe.recipe_ingredients.create!(name: "Filler #{i}", position: i) }
    edited = recipe.recipe_ingredients.create!(name: "Scallions", quantity: 1, unit: "bunch", position: 99)

    visit recipe_path(recipe)
    assert_selector "tr#ingredient-line-#{edited.id}" # gate on the page being loaded

    within "tr#ingredient-line-#{edited.id}" do
      # A zero amount fails numericality (greater_than: 0) so the edit is rejected.
      fill_in "Amount", with: "0"
    end
    # Submit the edit form directly (deterministic; dodges dropped clicks). The row
    # holds two forms sharing .inline-ingredient-form — the substitute add form and
    # this edit form — so target the edit form by its action.
    submit_form "form[action='#{recipe_ingredient_path(recipe, edited)}']"

    assert_text "must be greater than 0"
    assert row_in_view?(edited.id), "expected the rejected edit row to be scrolled into view"
  end

  private

  # Submit the first form matching `selector` via requestSubmit — a deterministic
  # native submission that isn't subject to the headless dropped-click flake.
  def submit_form(selector)
    page.execute_script(<<~JS, selector)
      const form = document.querySelector(arguments[0]);
      if (form) form.requestSubmit();
    JS
  end

  def row_in_view?(id)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#ingredient-line-#{id}");
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.top < window.innerHeight && r.bottom > 0;
      })()
    JS
  end

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
