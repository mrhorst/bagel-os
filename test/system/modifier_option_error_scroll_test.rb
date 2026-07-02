require "application_system_test_case"

# The modifier library's show page manages a group's options the same way a
# recipe manages its ingredient lines: an "Add option" form at the BOTTOM of the
# page plus an inline per-row edit, both submitting natively so the controller's
# place-preserving redirect fragment is honored on success. On FAILURE the
# controller re-renders the show page in place (keeping input + error), but the
# native submit lands the browser at the page TOP — so on a group with several
# options the error sits below the fold and the submit reads as a silent no-op.
# The scroll-into-view controller pulls the errored form/row back into view, the
# same guard the recipe show page already carries. These tests pin that.
class ModifierOptionErrorScrollTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  # Enough existing options that the "Add option" form (and the earlier rows)
  # sit well below the fold — the situation where being thrown to the page top
  # hides the error.
  def group_with_many_options
    group = ModifierGroup.create!(name: "Bread #{SecureRandom.hex(3)}", kind: "ingredient", min_select: 1, max_select: 1)
    %w[Kaiser White Rye Wheat Sourdough Ciabatta Multigrain Pumpernickel].each_with_index do |name, i|
      group.modifier_options.create!(name: name, position: i + 1)
    end
    group
  end

  test "a rejected Add option scrolls the error into view instead of stranding it at the top" do
    group = group_with_many_options

    visit modifier_group_path(group)
    assert_selector "#add-option" # gate on the page being loaded before submitting

    # Submit the add form with no inventory item and no name -> "Name can't be
    # blank". requestSubmit is deterministic (dodges the headless dropped-click
    # flake) and, because the form is data-turbo=false, performs the real native
    # navigation whose 422 re-render this test is about.
    submit_form "#add-option form"

    assert_text "Name can't be blank"
    assert form_in_view?("#add-option"),
      "expected the rejected Add option form to be scrolled into view"
    assert page.evaluate_script("window.pageYOffset") > 0,
      "expected the page to be scrolled down to the errored form, not left at the top"
  end

  test "a rejected inline option edit scrolls the errored row into view" do
    group = group_with_many_options
    edited = group.modifier_options.ordered.last # sits well below the fold

    visit modifier_group_path(group)
    assert_selector "tr#option-line-#{edited.id}" # gate on the page being loaded

    # Blank the name on the row's edit form (it has no inventory item) so the
    # save is rejected, then submit that specific form by its action.
    clear_field_and_submit(
      form_selector: "form[action='#{modifier_group_option_path(group, edited)}']",
      field_name: "modifier_option[name]"
    )

    assert_text "Name can't be blank"
    assert row_in_view?(edited.id), "expected the rejected edit row to be scrolled into view"
    assert page.evaluate_script("window.pageYOffset") > 0,
      "expected the page to be scrolled down to the errored row, not left at the top"
  end

  private

  def submit_form(selector)
    page.execute_script(<<~JS, selector)
      const form = document.querySelector(arguments[0]);
      if (form) form.requestSubmit();
    JS
  end

  # Clear a field inside `form_selector` (the row's edit form lives in a closed
  # <details>, so its input isn't visible for Capybara's fill_in) and submit
  # natively — deterministic and unaffected by the disclosure state.
  def clear_field_and_submit(form_selector:, field_name:)
    page.execute_script(<<~JS, form_selector, field_name)
      const form = document.querySelector(arguments[0]);
      if (!form) return;
      const field = form.querySelector(`[name='${arguments[1]}']`);
      if (field) field.value = "";
      form.requestSubmit();
    JS
  end

  def row_in_view?(id)
    element_in_view?("#option-line-#{id}")
  end

  def form_in_view?(selector)
    element_in_view?(selector)
  end

  def element_in_view?(selector)
    page.evaluate_script(<<~JS, selector)
      (() => {
        const el = document.querySelector(arguments[0]);
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.top < window.innerHeight && r.bottom > 0;
      })()
    JS
  end
end
