require "test_helper"

class InventoryCountsTest < ActionDispatch::IntegrationTest
  setup do
    @guide = OrderGuide.create!(name: "Weekly")
    @walk_in = @guide.section_named!("Walk-in")
    @freezer = @guide.section_named!("Freezer")
    @cream_cheese = InventoryItem.create!(name: "Cream Cheese", count_unit: "tub")
    @eggs = InventoryItem.create!(name: "Eggs", count_unit: "case")
    @air_freshener = InventoryItem.create!(name: "Air Freshener", count_unit: "each")
    @cream_membership = @cream_cheese.add_to_order_guide!(
      @guide,
      order_guide_section: @walk_in,
      tracking_mode: "counted",
      expected_usage_quantity: 4,
      buffer_quantity: 1
    )
    @egg_membership = @eggs.add_to_order_guide!(
      @guide,
      order_guide_section: @freezer,
      tracking_mode: "counted",
      expected_usage_quantity: 2,
      buffer_quantity: 1
    )
    @air_freshener.add_to_order_guide!(@guide, order_guide_section: @walk_in, tracking_mode: "order_only")
  end

  test "new count page groups countable rows by guide section and excludes order only rows" do
    get new_inventory_count_path(order_guide_id: @guide.id)

    assert_response :success
    assert_select "h1", text: "Count Weekly"
    assert_select "h2", text: "Walk-in"
    assert_select "h2", text: "Freezer"
    assert_match "Cream Cheese", response.body
    assert_match "Eggs", response.body
    assert_no_match "Air Freshener", response.body
  end

  test "inventory landing page starts from guide workflows instead of legacy par buy list" do
    get inventory_path

    assert_response :success
    assert_select "h2", text: "Guide Workflows"
    assert_match "Weekly", response.body
    assert_select "a[href='#{new_inventory_count_path(order_guide_id: @guide.id)}']", text: "Count"
    assert_select "a[href='#{inventory_shopping_list_path(order_guide_id: @guide.id)}']", text: "Buy list"
    assert_no_match "Next Buy List", response.body
    assert_no_match "par levels", response.body
  end

  test "creates a guide inventory count from submitted rows and skips blanks" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => ""
      }
    }

    assert_redirected_to inventory_shopping_list_path(order_guide_id: @guide.id)
    count = InventoryCount.last
    assert_equal @guide, count.order_guide
    assert_equal "Sunday morning count", count.notes
    assert_equal 1, count.inventory_count_lines.count
    line = count.inventory_count_lines.first
    assert_equal @cream_cheese, line.inventory_item
    assert_equal @cream_membership, line.order_guide_membership
    assert_equal BigDecimal("4.5"), line.quantity_on_hand
    assert_equal "tub", line.unit
  end

  test "an empty guide inventory count re-renders the form keeping the notes instead of redirecting them away" do
    # An empty submit is a recoverable mistake like any other on this form: the
    # guide is still active, so the form can be kept. Redirecting to a fresh form
    # used to silently drop the notes the user had already typed, inconsistent
    # with the bad-number / negative / removed-row paths that all re-render in
    # place. Re-render here too, preserving the note.
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: { @cream_membership.id => "" }
    }

    # Re-render in place (not a redirect that discards the typed notes).
    assert_response :unprocessable_entity
    assert_equal 0, InventoryCount.count
    # The user is told what to do, inline in the form...
    assert_select ".form-errors", text: /Enter at least one count/
    # ...and the note they already typed survives so they can add a count and
    # save without retyping it.
    assert_select "textarea[name=notes]", text: "Sunday morning count"
  end

  test "a count with one unparseable value re-renders the form keeping the other counts instead of dropping them" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => "2 cases" # not a number — BigDecimal would raise
      }
    }

    # Re-render in place (not a redirect that throws the whole count away).
    assert_response :unprocessable_entity
    assert_equal 0, InventoryCount.count

    # The bad row is named so the user knows exactly what to fix...
    assert_select ".form-errors", text: /Eggs/
    # ...the valid count the user already keyed in is still there...
    assert_select "input[name=?][value=?]", "counts[#{@cream_membership.id}]", "4.5"
    # ...the offending field is flagged...
    assert_select "input[name=?][aria-invalid=?]", "counts[#{@egg_membership.id}]", "true"
    # ...and the notes survive too.
    assert_select "textarea[name=notes]", text: "Sunday morning count"
  end

  test "a negative count re-renders the form keeping the other counts instead of crashing the save" do
    # The count line model rejects negatives (quantity_on_hand >= 0). A negative
    # parses fine as a number, so without a guard it would reach create! and
    # raise RecordInvalid mid-transaction — Rails renders that as a generic 422
    # error page, throwing away every count the user keyed in. It must instead
    # be treated like any other bad entry: re-render in place, keep the rest.
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => "-3"
      }
    }

    # Re-render in place, not a crash and not a redirect that discards the count.
    assert_response :unprocessable_entity
    assert_equal 0, InventoryCount.count

    # The offending row is named so the user knows what to fix...
    assert_select ".form-errors", text: /Eggs/
    # ...the value they keyed in is shown back so they can correct it...
    assert_select "input[name=?][value=?]", "counts[#{@egg_membership.id}]", "-3"
    assert_select "input[name=?][aria-invalid=?]", "counts[#{@egg_membership.id}]", "true"
    # ...their other valid count survives...
    assert_select "input[name=?][value=?]", "counts[#{@cream_membership.id}]", "4.5"
    # ...and so do the notes.
    assert_select "textarea[name=notes]", text: "Sunday morning count"
  end

  test "a row removed from the guide mid-count re-renders keeping the other counts instead of discarding the whole count" do
    # A row that was countable when the sheet loaded can stop being countable by
    # save time — another admin removes it from the guide. Without a guard the
    # save raised KeyError, redirected to the bare guide picker, and threw away
    # every count the user walked the floor to enter. It must instead behave like
    # any other recoverable problem: re-render in place, keep the rest.
    @egg_membership.deactivate!

    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => "2"
      }
    }

    # Re-render in place — not a redirect to the guide picker that discards the count.
    assert_response :unprocessable_entity
    assert_equal 0, InventoryCount.count

    # The removed row is named so the user understands what changed...
    assert_select ".form-errors", text: /Eggs/
    assert_select ".form-errors", text: /removed from this guide/
    # ...the valid count the user already keyed in is still there...
    assert_select "input[name=?][value=?]", "counts[#{@cream_membership.id}]", "4.5"
    # ...and the notes survive too, so saving again records the rest.
    assert_select "textarea[name=notes]", text: "Sunday morning count"
  end

  test "saving again after a row was removed records the remaining counts" do
    @egg_membership.deactivate!

    # First save hits the removed row and re-renders.
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: { @cream_membership.id => "4.5", @egg_membership.id => "2" }
    }
    assert_response :unprocessable_entity
    assert_equal 0, InventoryCount.count

    # The user saves again — the removed row no longer has a field, so only the
    # valid count is resubmitted and it now succeeds.
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: { @cream_membership.id => "4.5" }
    }
    assert_redirected_to inventory_shopping_list_path(order_guide_id: @guide.id)
    assert_equal 1, InventoryCount.count
    assert_equal BigDecimal("4.5"), InventoryCount.last.inventory_count_lines.first.quantity_on_hand
  end

  test "saving a count for a guide that was deactivated mid-count gives a clear alert" do
    @guide.update!(active: false)

    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: { @cream_membership.id => "4.5" }
    }

    assert_redirected_to new_inventory_count_path
    assert_equal "That guide is no longer active. Pick an active guide to count.", flash[:alert]
    assert_equal 0, InventoryCount.count
  end

  test "a negative legacy count surfaces a recoverable alert instead of crashing" do
    post inventory_counts_path, params: { counts: { @cream_cheese.id => "-2" } }

    assert_redirected_to new_inventory_count_path
    assert_equal "Each count must be a number of 0 or more.", flash[:alert]
    assert_equal 0, InventoryCount.count
  end

  test "counts list links each row to the count detail page" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: { @cream_membership.id => "4.5" }
    }
    count = InventoryCount.last

    get inventory_counts_path

    assert_response :success
    assert_select "a[href='#{inventory_count_path(count)}']"
  end

  test "count detail page lists the recorded lines so a saved count is traceable" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      notes: "Sunday morning count",
      counts: {
        @cream_membership.id => "4.5",
        @egg_membership.id => "2"
      }
    }
    count = InventoryCount.last

    get inventory_count_path(count)

    assert_response :success
    assert_select "h1", text: "Count: Weekly"
    assert_match "Sunday morning count", response.body
    # Each counted line is shown with its item, section, and quantity.
    assert_match "Cream Cheese", response.body
    assert_match "Walk-in", response.body
    assert_match "4.5", response.body
    assert_match "Eggs", response.body
    assert_match "Freezer", response.body
  end

  test "count detail page links forward to the guide buy list so the count-to-buy loop stays reachable" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: { @cream_membership.id => "4.5" }
    }
    count = InventoryCount.last

    get inventory_count_path(count)

    assert_response :success
    # Saving a count redirects to its guide's buy list; a count opened later
    # from history must offer that same next step instead of dead-ending.
    assert_select "a[href='#{inventory_shopping_list_path(order_guide_id: @guide.id)}']", text: "View buy list"
  end

  test "legacy count detail has no guide buy list link since it has no guide" do
    post inventory_counts_path, params: { counts: { @cream_cheese.id => "3" } }
    count = InventoryCount.last
    assert_nil count.order_guide

    get inventory_count_path(count)

    assert_response :success
    # No guide means no guide-specific buy list to link to.
    assert_select "a", text: "View buy list", count: 0
  end

  test "guide shopping list shows buy now setup not counted and order only sections" do
    post inventory_counts_path, params: {
      order_guide_id: @guide.id,
      counts: {
        @cream_membership.id => "2"
      }
    }

    unconfigured_item = InventoryItem.create!(name: "Napkins", count_unit: "case")
    unconfigured_item.add_to_order_guide!(@guide, order_guide_section: @walk_in, tracking_mode: "counted")

    get inventory_shopping_list_path(order_guide_id: @guide.id)

    assert_response :success
    assert_select "h1", text: "Weekly Buy List"
    assert_select "h2", text: "Buy Now"
    assert_match "Cream Cheese", response.body
    assert_match "Napkins", response.body
    assert_match "Eggs", response.body
    assert_match "Air Freshener", response.body
    assert_select ".badge", text: "Buy now"
  end
end
