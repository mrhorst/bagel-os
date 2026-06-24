require "test_helper"

class OrderGuidesManagementTest < ActionDispatch::IntegrationTest
  test "creates renames archives guides and assigns an inventory item primary guide" do
    section = InventorySection.create!(name: "Dairy", position: 1)
    item = InventoryItem.create!(name: "Cream Cheese", key: "cream-cheese", inventory_section: section)

    post order_guides_path, params: {
      order_guide: {
        name: "Every 2 weeks",
        notes: "Bulk items that do not need daily review."
      }
    }

    guide = OrderGuide.find_by!(name: "Every 2 weeks")
    assert_redirected_to order_guides_path
    assert guide.active?

    get inventory_items_path
    assert_response :success
    assert_select "select[name='order_guide_id'] option", text: "Every 2 weeks"

    patch inventory_item_primary_order_guide_path(item), params: { order_guide_id: guide.id }

    assert_redirected_to inventory_items_path
    assert_equal guide, item.reload.primary_order_guide

    get order_guides_path
    assert_response :success
    assert_select "a", text: "CSV example"
    assert_no_match "Import current PDFs", response.body
    assert_select "h2", text: "Items By Guide"
    assert_match "Cream Cheese", response.body

    get order_guide_path(guide)
    assert_response :success
    assert_select "h1", text: "Every 2 weeks"
    assert_select "h2", text: "Add Existing Operating Item"
    assert_match "Cream Cheese", response.body

    patch order_guide_path(guide), params: { order_guide: { name: "Every other week" } }
    assert_redirected_to order_guides_path
    assert_equal "Every other week", guide.reload.name

    delete order_guide_path(guide)
    assert_redirected_to order_guides_path
    assert_not guide.reload.active?
    assert_nil item.reload.primary_order_guide
  end

  test "creating a guide whose name is already taken explains it in name terms" do
    OrderGuide.create!(name: "Daily")

    post order_guides_path, params: { order_guide: { name: "Daily" } }

    # A manager retyping an existing guide name must get a clear, recoverable
    # message — not the internal "Key has already been taken" that leaks the
    # derived slug field they never see.
    assert_redirected_to order_guides_path
    assert_equal %(A guide named "Daily" already exists. Pick a different name.), flash[:alert]
    assert_not_includes flash[:alert].to_s, "Key"
    assert_equal 1, OrderGuide.where(name: "Daily").count
  end

  test "archive button on the guides index guards with a confirmation" do
    guide = OrderGuide.create!(name: "Daily")
    item = InventoryItem.create!(name: "Eggs", key: "eggs")
    item.add_to_order_guide!(guide, tracking_mode: "counted")

    get order_guides_path
    assert_response :success

    # The Archive control destroys (soft-archives) the guide AND cascades to
    # deactivate every membership on it — the same convention as archiving a
    # task list or task, both of which confirm first. It must not fire on a
    # single mis-tap with no guard.
    assert_select "form[action=?]", order_guide_path(guide) do
      assert_select "button[data-turbo-confirm][type=submit]", text: "Archive"
    end
  end

  test "remove button on a guide item guards with a confirmation" do
    guide = OrderGuide.create!(name: "Daily")
    item = InventoryItem.create!(name: "Eggs", key: "eggs")
    item.add_to_order_guide!(guide, tracking_mode: "counted")
    membership = guide.order_guide_memberships.find_by!(inventory_item: item)

    get order_guide_path(guide)
    assert_response :success

    # Removing an item soft-deletes its membership and discards its configured
    # usage/buffer/section setup — re-adding means reconfiguring from scratch.
    # The sibling Archive control on the index already guards against a mis-tap;
    # the per-item Remove must too, matching every other destructive control.
    assert_select "form[action=?]", order_guide_membership_path(guide, membership) do
      assert_select "button[data-turbo-confirm][type=submit]", text: "Remove"
    end
  end

  test "guide show page surfaces the staff note collected at creation" do
    # The "Create Guide" form collects a free-text note ("Optional staff note
    # for how this guide is used.") into OrderGuide#notes, but nothing rendered
    # it back — the value was write-only, so the note a manager wrote vanished
    # with no way to see it. It must appear where staff use the guide.
    guide = OrderGuide.create!(name: "Daily", notes: "Count before the morning order.\nFlag anything short.")

    get order_guide_path(guide)

    assert_response :success
    assert_select ".note-block", text: /Guide note/
    assert_select ".note-block", text: /Count before the morning order\./
    # simple_format splits the two lines into separate paragraphs (no invalid
    # <p> nesting — see #191), so both lines render.
    assert_select ".note-block p", text: /Flag anything short\./
  end

  test "guide show page omits the note block when the guide has no note" do
    guide = OrderGuide.create!(name: "Weekly", notes: "")

    get order_guide_path(guide)

    assert_response :success
    assert_select ".note-block", count: 0
  end

  test "downloads csv example for order guide import shape" do
    get csv_example_order_guides_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "guide_name,item_name,section,category,count_unit,pack_size,primary_guide,position,notes"
    assert_includes response.body, "Daily,Eggs,Walk-in cooler"
  end

  test "adds removes and re-adds existing inventory items from a guide" do
    guide = OrderGuide.create!(name: "Daily")
    section = InventorySection.create!(name: "Walk-in cooler", position: 1)
    item = InventoryItem.create!(name: "Eggs", key: "eggs", inventory_section: section)

    get order_guide_path(guide)
    assert_response :success
    assert_select "select[name='membership[inventory_item_id]'] option", text: "Eggs"

    post order_guide_memberships_path(guide), params: {
      membership: {
        inventory_item_id: item.id,
        section_name: "Walk-in cooler",
        tracking_mode: "counted",
        expected_usage_quantity: "6",
        buffer_quantity: "2"
      }
    }

    assert_redirected_to order_guide_path(guide)
    membership = guide.order_guide_memberships.find_by!(inventory_item: item)
    assert membership.active?
    assert_equal "Walk-in cooler", membership.order_guide_section.name
    assert_equal BigDecimal("8"), membership.target_after_order

    get order_guide_path(guide)
    assert_response :success
    assert_match "Eggs", response.body
    assert_select "form[action='#{order_guide_membership_path(guide, membership)}']"

    delete order_guide_membership_path(guide, membership)

    assert_redirected_to order_guide_path(guide)
    assert_not membership.reload.active?

    get order_guide_path(guide)
    assert_response :success
    assert_no_match(/<strong>Eggs<\/strong>/, response.body)
    assert_select "select[name='membership[inventory_item_id]'] option", text: "Eggs"

    post order_guide_memberships_path(guide), params: {
      membership: {
        inventory_item_id: item.id,
        section_name: "Walk-in cooler",
        tracking_mode: "order_only"
      }
    }

    assert_redirected_to order_guide_path(guide)
    assert membership.reload.active?
    assert membership.order_only?
    assert_equal 1, guide.order_guide_memberships.where(inventory_item: item).count
  end

  test "adding an item with no item chosen keeps the user on the guide, not the index" do
    guide = OrderGuide.create!(name: "Daily")
    InventoryItem.create!(name: "Eggs", key: "eggs")

    post order_guide_memberships_path(guide), params: {
      membership: {
        inventory_item_id: "", # user forgot to pick an item
        section_name: "Walk-in cooler",
        expected_usage_quantity: "6"
      }
    }

    # The failed add must return to the guide being edited — not bounce the
    # user out to the all-guides index and lose their place.
    assert_redirected_to order_guide_path(guide)
    assert_equal "Choose an inventory item to add to this guide.", flash[:alert]
    assert_equal 0, guide.order_guide_memberships.active.count
  end

  test "a failed add against a missing guide falls back to the index" do
    item = InventoryItem.create!(name: "Eggs", key: "eggs")

    post order_guide_memberships_path(order_guide_id: 0), params: {
      membership: { inventory_item_id: item.id, section_name: "Dry storage" }
    }

    # No guide to return to, so the index is the only sensible destination.
    assert_redirected_to order_guides_path
    assert flash[:alert].present?
  end

  test "a failed inline row update keeps the user on the guide" do
    guide = OrderGuide.create!(name: "Weekly")
    item = InventoryItem.create!(name: "Bacon", key: "bacon")
    membership = item.add_to_order_guide!(guide, tracking_mode: "counted")

    # An invalid tracking_mode trips the model's inclusion validation, so
    # update! raises — the same rescue path that used to bounce to the index.
    patch order_guide_membership_path(guide, membership), params: {
      membership: { section_name: "Freezer", tracking_mode: "nonsense" }
    }

    assert_redirected_to order_guide_path(guide)
    assert flash[:alert].present?
    assert_equal "counted", membership.reload.tracking_mode
  end

  test "updates guide membership setup fields inline" do
    guide = OrderGuide.create!(name: "Weekly")
    item = InventoryItem.create!(name: "Bacon", key: "bacon")
    membership = item.add_to_order_guide!(guide, tracking_mode: "counted")

    patch order_guide_membership_path(guide, membership), params: {
      membership: {
        section_name: "Freezer",
        tracking_mode: "counted",
        expected_usage_quantity: "2",
        buffer_quantity: "1"
      }
    }

    assert_redirected_to order_guide_path(guide)
    assert_equal "Freezer", membership.reload.order_guide_section.name
    assert_equal BigDecimal("3"), membership.target_after_order
  end

  test "removing primary item from guide leaves item without primary guide" do
    guide = OrderGuide.create!(name: "Weekly")
    item = InventoryItem.create!(name: "Coffee beans", key: "coffee-beans")
    membership = item.add_to_order_guide!(guide, primary: true)

    delete order_guide_membership_path(guide, membership)

    assert_redirected_to order_guide_path(guide)
    assert_not membership.reload.active?
    assert_nil item.reload.primary_order_guide
  end

  test "changing primary guide from master inventory reactivates membership" do
    guide = OrderGuide.create!(name: "Every 2 weeks")
    item = InventoryItem.create!(name: "Napkins", key: "napkins")
    membership = item.add_to_order_guide!(guide, primary: true)
    membership.deactivate!

    patch inventory_item_primary_order_guide_path(item), params: { order_guide_id: guide.id }

    assert_redirected_to inventory_items_path
    assert membership.reload.active?
    assert membership.primary_guide?
    assert_equal guide, item.reload.primary_order_guide
  end
end
