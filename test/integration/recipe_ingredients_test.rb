require "test_helper"

class RecipeIngredientsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @recipe = recipes(:bagel_dough)
    @flour = InventoryItem.create!(name: "All-purpose flour", key: "all-purpose-flour")
  end

  test "adds an ingredient linked to an inventory item" do
    assert_difference -> { @recipe.recipe_ingredients.count }, 1 do
      post recipe_ingredients_path(@recipe), params: {
        recipe_ingredient: { inventory_item_id: @flour.id, quantity: "5", unit: "lb" }
      }
    end

    # After an add, return to the add form (bottom of the page) so the next line
    # can be entered without scrolling back past the whole table.
    assert_redirected_to recipe_path(@recipe, anchor: "add-ingredient")
    line = @recipe.recipe_ingredients.order(:id).last
    assert_equal @flour, line.inventory_item
    assert_equal BigDecimal("5"), line.quantity
    assert_equal "lb", line.unit

    get recipe_path(@recipe)
    assert_select "td.row-heading", text: /All-purpose flour/
  end

  test "adds a free-text ingredient with an unknown amount and unit left blank" do
    post recipe_ingredients_path(@recipe), params: {
      recipe_ingredient: { name: "Pinch of malt", quantity: "", unit: "" }
    }

    assert_redirected_to recipe_path(@recipe, anchor: "add-ingredient")
    line = @recipe.recipe_ingredients.order(:id).last
    assert_nil line.inventory_item
    assert_equal "Pinch of malt", line.name
    # Unknown amount/unit stay blank — never inferred.
    assert_nil line.quantity
    assert line.unit.blank?
  end

  test "a deliberately-blank amount reads as blank, not 'n/a'" do
    recipe = Recipe.create!(name: "Blank-amount probe", active: true, position: 999)
    # A line whose amount is intentionally unknown — the feature promises these
    # are left blank, never guessed. It must read like the blank Unit beside it
    # (the app's "—" convention), not "n/a", which reads as a system error.
    recipe.recipe_ingredients.create!(name: "Salt to taste", quantity: nil, unit: nil, position: 1)
    # A line with a real amount still shows the number.
    recipe.recipe_ingredients.create!(name: "Flour", quantity: 5, unit: "cup", position: 2)

    get recipe_path(recipe)
    assert_response :success
    assert_select %(td[data-label="Amount"]), text: "—"
    assert_select %(td[data-label="Amount"]), text: "5"
    assert_select %(td[data-label="Amount"]), text: "n/a", count: 0
  end

  test "rejecting an ingredient with no item and no name re-renders in place keeping input" do
    assert_no_difference -> { @recipe.recipe_ingredients.count } do
      post recipe_ingredients_path(@recipe), params: {
        recipe_ingredient: { inventory_item_id: "", name: "", quantity: "3", unit: "cup" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".flash-alert"
    # The typed amount/unit survive the failed add.
    assert_select "input[name=?][value=?]", "recipe_ingredient[quantity]", "3"
    assert_select "input[name=?][value=?]", "recipe_ingredient[unit]", "cup"
  end

  test "an ingredient linked to a since-archived item stays selected and editable" do
    # An inventory item can be deactivated through normal operation (e.g. an
    # order-guide re-import deactivates an item with no guide types or counts —
    # Purchasing::OrderGuideImporter). A recipe line already linked to it must not
    # become a dead end: before the fix the edit dropdown offered only active
    # items, so the archived link silently vanished from the select (read as "No
    # item") and saving any edit blanked the link and failed with "Name can't be
    # blank" on a line that visibly HAS an inventory item.
    line = @recipe.recipe_ingredients.create!(inventory_item: @flour, quantity: 5, unit: "lb")
    @flour.update!(active: false)

    get recipe_path(@recipe)
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    edit_form = doc.at_css("form[action='#{recipe_ingredient_path(@recipe, line)}']")
    assert edit_form, "expected an inline edit form for the linked line"
    select = edit_form.at_css("select[name='recipe_ingredient[inventory_item_id]']")
    selected = select.css("option[selected]").first
    assert selected, "the edit dropdown must keep the archived linked item selected, not drop it"
    assert_equal @flour.id.to_s, selected["value"]
    assert_match(/archived/i, selected.text, "the archived item should be labelled so")

    # And the line remains editable: a save carrying the (preserved) item id keeps
    # the link instead of 422-ing on a phantom missing name.
    patch recipe_ingredient_path(@recipe, line), params: {
      recipe_ingredient: { inventory_item_id: @flour.id, quantity: "6", unit: "lb" }
    }
    assert_redirected_to recipe_path(@recipe, anchor: "ingredient-line-#{line.id}")
    assert_equal @flour, line.reload.inventory_item
    assert_equal BigDecimal("6"), line.quantity
  end

  test "updates an ingredient line" do
    line = @recipe.recipe_ingredients.create!(inventory_item: @flour, quantity: 5, unit: "lb")

    patch recipe_ingredient_path(@recipe, line), params: {
      recipe_ingredient: { inventory_item_id: @flour.id, quantity: "6", unit: "lb" }
    }

    assert_redirected_to recipe_path(@recipe, anchor: "ingredient-line-#{line.id}")
    assert_equal BigDecimal("6"), line.reload.quantity
  end

  test "removes an ingredient line" do
    line = @recipe.recipe_ingredients.create!(name: "Water", quantity: 2, unit: "cup")

    assert_difference -> { @recipe.recipe_ingredients.count }, -1 do
      delete recipe_ingredient_path(@recipe, line)
    end

    assert_redirected_to recipe_path(@recipe)
  end

  test "the recipe show page offers an add-ingredient form" do
    get recipe_path(@recipe)

    assert_response :success
    assert_select "form[action=?]", recipe_ingredients_path(@recipe)
    assert_select "h2", text: "Ingredients"
    assert_select "h2", text: "Add ingredient"
  end

  test "ingredient form fields stay uniquely id'd across rows so labels point to their own field" do
    # Several rows mean several inline edit forms PLUS the add form, all from the
    # shared partial. Without a per-form namespace they emitted identical field
    # ids (recipe_ingredient_name, …) — duplicate ids are invalid HTML and make
    # every <label for> resolve to the FIRST match, so clicking a label focused
    # row 1's input instead of the field beneath it.
    @recipe.recipe_ingredients.create!(name: "Water", quantity: 2, unit: "cup")
    @recipe.recipe_ingredients.create!(inventory_item: @flour, quantity: 5, unit: "lb")

    get recipe_path(@recipe)
    assert_response :success

    ids = Nokogiri::HTML(response.body).css("[id]").map { |n| n["id"] }
    duplicates = ids.tally.select { |_id, count| count > 1 }.keys
    assert_empty duplicates, "Recipe show page has duplicate element ids: #{duplicates.inspect}"

    # The add form's visible "Amount" label must point at an input that exists and
    # sits inside the same (add) form — not at a stray duplicate elsewhere.
    doc = Nokogiri::HTML(response.body)
    add_form = doc.at_css("form[action='#{recipe_ingredients_path(@recipe)}']")
    amount_label = add_form.css("label").find { |l| l.text.strip == "Amount" }
    assert amount_label, "expected an 'Amount' label on the add-ingredient form"
    target = add_form.at_css("##{amount_label['for']}")
    assert target, "the 'Amount' label's for=#{amount_label['for'].inspect} must resolve to a field within the add form"
    assert_equal "recipe_ingredient[quantity]", target["name"]
  end

  test "add and edit redirects carry a place-preserving fragment that exists on the page" do
    # Building a recipe means adding line after line from the form at the BOTTOM
    # of the show page. A bare redirect dropped the user at the page top after
    # every add, so each new line meant scrolling back past the whole table. The
    # add/edit redirects now carry a fragment, the forms submit natively (so the
    # browser honors it), and the show page must actually render those targets.
    post recipe_ingredients_path(@recipe), params: {
      recipe_ingredient: { inventory_item_id: @flour.id, quantity: "5", unit: "lb" }
    }
    assert_redirected_to recipe_path(@recipe, anchor: "add-ingredient")
    line = @recipe.recipe_ingredients.order(:id).last

    patch recipe_ingredient_path(@recipe, line), params: {
      recipe_ingredient: { inventory_item_id: @flour.id, quantity: "6", unit: "lb" }
    }
    assert_redirected_to recipe_path(@recipe, anchor: "ingredient-line-#{line.id}")

    get recipe_path(@recipe)
    assert_response :success
    # Each redirect target must resolve to a real element, or the browser lands
    # nowhere and the place-preservation silently breaks.
    assert_select "#add-ingredient"
    assert_select "tr#ingredient-line-#{line.id}"
    # The forms submit natively so the redirect fragment isn't stripped by Turbo.
    assert_select "form[action=?][data-turbo='false']", recipe_ingredients_path(@recipe)
    assert_select "form[action=?][data-turbo='false']", recipe_ingredient_path(@recipe, line)
  end

  test "the show page shows a total when every line is costed and flags uncertain ones" do
    @flour.update!(product: priced_product("Flour stock", price: 2, unit: "lb"))
    @recipe.recipe_ingredients.create!(inventory_item: @flour, quantity: 5, unit: "lb")

    get recipe_path(@recipe)
    assert_response :success
    # 5 lb * $2.00 = $10.00, and a complete total is shown.
    assert_select ".recipe-cost-total strong", text: /\$10\.00/

    # Add a free-text line with no price source — the total becomes a partial and
    # the line is flagged uncertain with a reason instead of an invented number.
    @recipe.recipe_ingredients.create!(name: "Pinch of malt", quantity: 1, unit: "pinch")

    get recipe_path(@recipe)
    assert_response :success
    assert_select ".recipe-cost-summary", text: /Estimated cost so far/
    assert_select "td", text: /Not linked to an inventory item/
  end

  private

  def priced_product(name, price:, unit:)
    product = Supplier.primary.products.create!(canonical_name: name)
    batch = Supplier.primary.import_batches.create!(
      source_filename: "c.csv", file_checksum: SecureRandom.hex(8),
      status: "imported", imported_at: Time.current, rows_processed: 1, rows_imported: 1
    )
    receipt = Supplier.primary.receipts.create!(
      import_batch: batch, receipt_number: "R-#{SecureRandom.hex(4)}",
      purchased_at: Time.current, subtotal: 1, tax: 0, total: 1
    )
    line = receipt.receipt_line_items.create!(
      supplier: Supplier.primary, import_batch: batch, line_number: 1, line_type: "item",
      raw_name: "x", row_checksum: SecureRandom.hex(16)
    )
    PriceObservation.create!(
      product: product, receipt_line_item: line, supplier: Supplier.primary,
      observed_at: Time.current, source_filename: "c.csv",
      standard_unit_price: price, standard_unit: unit
    )
    product
  end
end
