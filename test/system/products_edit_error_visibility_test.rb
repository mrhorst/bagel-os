require "application_system_test_case"

# Editing a product happens on a long, multi-section form (Identity, Default
# units, How it's used, Notes, Review decision, Receipt names) whose "Save
# product" / "Save and mark reviewed" buttons sit at the very BOTTOM. The form
# submits via Turbo, so a rejected save re-renders the page in place (keeping the
# typed input and its error) and — like every Turbo navigation — lands the
# browser at the page TOP.
#
# The error banner sits INSIDE the form panel, below the review-summary band, so
# scroll-to-top used to leave it out of view: the user tapped Save at the bottom,
# the viewport jumped a full form-length up to an unchanged-looking heading +
# summary band, and the reason the save failed was stranded below it — a rejected
# save that reads as a silent no-op. The banner now carries the scroll-into-view
# controller (mirroring the recipe form fix #413), so a rejected save pulls the
# error into view instead of leaving the browser at the page top.
class ProductsEditErrorVisibilityTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    supplier = Supplier.create!(name: "Probe Supplier")
    @product = Product.create!(canonical_name: "Probe Product", supplier: supplier)
  end

  test "a rejected save scrolls its error into view instead of stranding it at the page top" do
    # A phone-sized viewport is where landing at the page top with the error below
    # the summary band actually hides it.
    page.driver.browser.manage.window.resize_to(414, 896)

    visit edit_product_path(@product)
    assert_selector "form.product-edit-form"

    # Fill the each-weight VALUE but leave its UNIT blank: the model rejects a
    # half-filled weight bridge ("...must be filled in together"), giving us a
    # deterministic server-side validation failure.
    fill_in "Average weight per unit", with: "50"
    fill_in "Weight unit", with: ""

    # Submit from the bottom of the form (where the buttons live) via requestSubmit
    # — deterministic, dodging the headless dropped-click flake.
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    submit_form "form.product-edit-form"

    # The save was rejected and re-rendered in place with the error…
    assert_text "must be filled in together"
    assert_equal edit_product_path(@product), URI(page.current_url).path
    # …the typed input survived the re-render…
    assert_equal "50", find("#product_each_weight_value").value

    # …and the error banner was scrolled into view rather than left at the page top
    # while the browser sits above the fold.
    assert error_banner_in_view?,
      "expected the rejected-save error banner to be scrolled into view"
    assert page.evaluate_script("window.pageYOffset") > 0,
      "expected the page to be scrolled down to the errored banner, not left at the top"
  end

  private

  def submit_form(selector)
    page.execute_script(<<~JS, selector)
      const form = document.querySelector(arguments[0]);
      if (form) form.requestSubmit();
    JS
  end

  def error_banner_in_view?
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(".flash-alert");
        if (!el) return false;
        const r = el.getBoundingClientRect();
        return r.top >= 0 && r.top < window.innerHeight && r.bottom > 0;
      })()
    JS
  end
end
