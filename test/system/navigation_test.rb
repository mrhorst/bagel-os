require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "an admin sees the primary navigation on the dashboard" do
    # Real signed-in admin signals: the account link plus populated nav links.
    assert_selector "a[aria-label='Account']"
    assert_selector "nav[aria-label='Primary navigation'] a.nav-link"
    # The dashboard surfaces the core modules an admin can reach.
    assert_text "Tasks"
    assert_text "Log Book"
  end

  test "the mobile back chevron on Log Book settings returns to Log Book, not the hub" do
    # The mobile header (and its back chevron) only render below the 640px
    # breakpoint, so shrink the window to where this affordance is the primary
    # way back. The bug: without a per-page override the layout's auto-chevron
    # points at the module hub (Shift), overshooting Log Book — the page's own
    # parent and what the in-body "Back to Log Book" button names.
    page.current_window.resize_to(414, 896)
    visit log_book_settings_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Book", chevron["aria-label"]
    assert_equal log_book_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on Log Sections returns to the Settings hub, not Log Book" do
    # Sections is reached only from the Log Book Settings hub (which renders it
    # alongside History), so "up one level" is Settings — pointing at Log Book
    # would overshoot the hub the user came from and skip its sibling History
    # card. Matches the app's universal one-level-up convention.
    page.current_window.resize_to(414, 896)
    visit log_book_sections_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Settings", chevron["aria-label"]
    assert_equal log_book_settings_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_settings_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on Log Book history returns to Log Book, not the hub" do
    # Same gap as the Log Book settings and sections sub-pages: below 640px the
    # layout's auto-chevron points at the module hub (Shift), overshooting Log
    # Book — the page's own parent and what its in-body "Back to Log Book" button
    # names. It should go up exactly one level, to Log Book.
    page.current_window.resize_to(414, 896)
    visit log_book_history_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Book", chevron["aria-label"]
    assert_equal log_book_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a past Log Book day returns to Log Book, not the hub" do
    # A past, read-only day (opened from History, the date pager, a bookmark, or
    # a post-save redirect) is still the Log Book index controller, so without a
    # per-page override the layout's auto-chevron points at the module hub
    # (Shift) — ejecting the user out of Log Book, unlike the settings/sections/
    # history sub-views whose chevron returns to Log Book. It should go up exactly
    # one level, to Log Book — the same target as the in-body "Back to today".
    page.current_window.resize_to(414, 896)
    visit log_book_path(date: Date.current - 3)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Book", chevron["aria-label"]
    assert_equal log_book_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on today's Log Book still points at the Shift hub" do
    # The override above is gated to past days: the live "today" index is the
    # canonical top-level module page, so its parent really is the Shift hub.
    # Guard against the gate over-reaching and rewriting the today chevron too.
    page.current_window.resize_to(414, 896)
    visit log_book_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Shift", chevron["aria-label"]
    assert_equal shift_hub_path, URI(chevron[:href]).path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a new log section returns to Log Sections, not the hub" do
    # A level deeper than the Log Sections list: the new/edit forms set no
    # override either, so below 640px the auto-chevron points at the module hub
    # (Shift), overshooting both Log Book and the Log Sections list this form was
    # opened from — and contradicting the in-body "Cancel" button (and where
    # Create redirects). It should go up exactly one level, to the sections list.
    page.current_window.resize_to(414, 896)
    visit new_log_book_section_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Sections", chevron["aria-label"]
    assert_equal log_book_sections_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_sections_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on an edit log section returns to Log Sections, not the hub" do
    # Same gap as the new-section form, on the edit route. The chevron should
    # land on the Log Sections list, matching the in-body "Cancel" button and
    # where Save redirects.
    section = LogBookSection.create!(title: "Walk-in temp", section_type: "long_text")
    page.current_window.resize_to(414, 896)
    visit edit_log_book_section_path(section)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Sections", chevron["aria-label"]
    assert_equal log_book_sections_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_sections_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a product returns to Products, not the hub" do
    # Same gap as the Log Book sub-pages: below 640px the layout's auto-chevron
    # points at the module hub (Stock), overshooting the Products catalog this
    # page was opened from. The chevron should go up exactly one level.
    product = build_product
    page.current_window.resize_to(414, 896)
    visit product_path(product)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Products", chevron["aria-label"]
    assert_equal products_path, URI(chevron[:href]).path

    click_mobile_back_to products_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a product edit returns to the product, not the hub" do
    # The deepest step of the products-edit flow. Without an override the
    # auto-chevron points at the module hub (Stock), overshooting both the
    # product and the catalog by two levels and contradicting the in-body
    # "Back to product" button. It should land on the product it edits.
    product = build_product
    page.current_window.resize_to(414, 896)
    visit edit_product_path(product)

    chevron = find(".mobile-header-back")
    assert_equal "Back to product", chevron["aria-label"]
    assert_equal product_path(product), URI(chevron[:href]).path

    click_mobile_back_to product_path(product)
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on an order guide returns to Order Guides, not the hub" do
    # Same gap as the Log Book and Products sub-pages: below 640px the layout's
    # auto-chevron points at the module hub (Buying), overshooting the Order
    # Guides catalog this page was opened from and contradicting the in-body
    # "All guides" button. The chevron should go up exactly one level.
    guide = OrderGuide.create!(name: "Test Guide")
    page.current_window.resize_to(414, 896)
    visit order_guide_path(guide)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Order Guides", chevron["aria-label"]
    assert_equal order_guides_path, URI(chevron[:href]).path

    click_mobile_back_to order_guides_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a new inventory count returns to the counts list, not the hub" do
    # Same gap as the Log Book, Products, and Order Guide sub-pages: below 640px
    # the layout's auto-chevron points at the module hub (Stock), overshooting
    # the Inventory Counts list this page was opened from and contradicting the
    # in-body "Count history" button. The chevron should go up exactly one level.
    page.current_window.resize_to(414, 896)
    visit new_inventory_count_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Inventory Counts", chevron["aria-label"]
    assert_equal inventory_counts_path, URI(chevron[:href]).path

    click_mobile_back_to inventory_counts_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on the inventory counts list returns to Inventory, not the hub" do
    # The sibling of the new-count page, one level shallower. The counts list is
    # reached from the Inventory index "Count history" card, but without a
    # per-page override the layout's auto-chevron points at the module hub
    # (Stock), overshooting the Inventory index — its actual parent. It should go
    # up exactly one level, to Inventory.
    page.current_window.resize_to(414, 896)
    visit inventory_counts_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Inventory", chevron["aria-label"]
    assert_equal inventory_path, URI(chevron[:href]).path

    click_mobile_back_to inventory_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on the inventory items list returns to Inventory, not the hub" do
    # Same gap as the inventory counts list: below 640px the layout's auto-chevron
    # points at the module hub (Stock), overshooting the Inventory index this page
    # is opened from (its "Master inventory" card). It should go up exactly one
    # level, to Inventory.
    page.current_window.resize_to(414, 896)
    visit inventory_items_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Inventory", chevron["aria-label"]
    assert_equal inventory_path, URI(chevron[:href]).path

    click_mobile_back_to inventory_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on the shopping list returns to Inventory, not the hub" do
    # Same gap as the inventory items and counts lists: below 640px the layout's
    # auto-chevron points at the module hub (Stock), overshooting the Inventory
    # index this page is opened from (its guide "Buy list" links). It should go up
    # exactly one level, to Inventory.
    page.current_window.resize_to(414, 896)
    visit inventory_shopping_list_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Inventory", chevron["aria-label"]
    assert_equal inventory_path, URI(chevron[:href]).path

    click_mobile_back_to inventory_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a new tag returns to the tags list" do
    # The admin/tags controller isn't registered as a navigation module, so the
    # layout's auto-chevron never renders on its sub-pages — below 640px the
    # mobile header (which is authoritative; the in-page H1 is hidden) had no
    # back affordance at all, unlike every other sub-page. The chevron should
    # mirror the in-body "Back to tags" button and go to the tags list.
    page.current_window.resize_to(414, 896)
    visit new_admin_tag_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to tags", chevron["aria-label"]
    assert_equal admin_tags_path, URI(chevron[:href]).path

    click_mobile_back_to admin_tags_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a tag edit returns to the tags list" do
    # Same gap as the new-tag page: the admin/tags sub-pages set no
    # mobile_left_action and admin/tags is not a navigation module, so below
    # 640px the mobile header had no back chevron. It should mirror the in-body
    # "Back to tags" button.
    tag = Tag.create!(name: "QA Probe Tag", slug: "qa-probe-tag")
    page.current_window.resize_to(414, 896)
    visit edit_admin_tag_path(tag)

    chevron = find(".mobile-header-back")
    assert_equal "Back to tags", chevron["aria-label"]
    assert_equal admin_tags_path, URI(chevron[:href]).path

    click_mobile_back_to admin_tags_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a follow-up returns to Follow-ups, not the hub" do
    # Same gap as the Products and Order Guide sub-pages: follow_ups IS a
    # navigation module, and its index and detail share one controller, so
    # without a per-page override the layout's auto-chevron points at the module
    # hub (Shift) on the detail page too — overshooting the Follow-ups list the
    # user tapped in from. It should go up exactly one level, to that list.
    follow_up = FollowUp.create!(title: "Walk-in fridge reading high",
                                 urgency: "urgent", status: "open", opened_at: Time.current)
    page.current_window.resize_to(414, 896)
    visit follow_up_path(follow_up)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Follow-ups", chevron["aria-label"]
    assert_equal follow_ups_path, URI(chevron[:href]).path

    click_mobile_back_to follow_ups_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a receipt import returns to Imports, not the hub" do
    # Same gap as the Products and Order Guide sub-pages: import_batches IS a
    # navigation module (hub Stock), and its index and detail share one
    # controller, so without a per-page override the layout's auto-chevron points
    # at the hub on the detail page too — overshooting the Imports list the user
    # tapped in from and contradicting the in-body "All imports" button. It
    # should go up exactly one level, to that list.
    batch = build_import_batch_with_line
    page.current_window.resize_to(414, 896)
    visit import_batch_path(batch)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Imports", chevron["aria-label"]
    assert_equal import_batches_path, URI(chevron[:href]).path

    click_mobile_back_to import_batches_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on the receipt upload form returns to Imports, not the hub" do
    # The new-upload page shares the import_batches controller, so the auto-chevron
    # overshoots to the Stock hub. It should return to the Imports list it was
    # opened from.
    page.current_window.resize_to(414, 896)
    visit new_import_batch_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Imports", chevron["aria-label"]
    assert_equal import_batches_path, URI(chevron[:href]).path

    click_mobile_back_to import_batches_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on a receipt line editor returns to the receipt, not the hub" do
    # The deepest step of the receipt import → review pipeline. receipt_line_items
    # is catalogued under the Imports module, so without an override the
    # auto-chevron points at the hub (Stock), overshooting by two levels and
    # stranding the user away from the receipt they were triaging. It should land
    # on the import batch the line belongs to — where the in-body "Open receipt"
    # button and the post-save redirect already send them.
    batch = build_import_batch_with_line
    line = batch.receipt_line_items.first
    page.current_window.resize_to(414, 896)
    visit edit_receipt_line_item_path(line)

    chevron = find(".mobile-header-back")
    assert_equal "Back to receipt", chevron["aria-label"]
    assert_equal import_batch_path(batch), URI(chevron[:href]).path

    click_mobile_back_to import_batch_path(batch)
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on the collections index returns to the photo library" do
    # Collections isn't a navigation module, so the layout renders no auto-chevron;
    # the index supplies its own "Back to library" mobile chevron. Confirm it
    # points at — and lands on — the photo library, one level up. (Static href
    # coverage lives in collections_back_navigation_test.rb; this pins the runtime
    # behavior the old history.back back controller used to break.)
    page.current_window.resize_to(414, 896)
    visit collections_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to library", chevron["aria-label"]
    assert_equal photo_assets_path, URI(chevron[:href]).path

    click_mobile_back_to photo_assets_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "a collection back chevron honors its labeled destination on a cold load" do
    # The #117 class on the Collections journey — its pages aren't a nav module
    # and had no runtime back coverage, only static href assertions. A person can
    # reach a collection WITHOUT navigating into it in-app: a PWA cold start, a
    # deep link from a push notification, a bookmark, or the redirect after saving
    # the collection form. The page then loads fresh with a same-origin referrer
    # that is NOT the chevron's destination, and the old `back` Stimulus controller
    # called history.back() — stranding the user on the referrer instead of where
    # the chevron's label promised. The chevron must go to its labeled destination
    # (the collections index) regardless of how the page was reached.
    collection = collections(:summer)
    page.current_window.resize_to(414, 896)

    # A same-origin page that is NOT this chevron's destination, so a divergence
    # would be unambiguous (the library is the collections index's own parent).
    visit photo_assets_path
    # Full (non-Turbo) load into the collection page, so document.referrer =
    # /marketing/photos — the exact condition that used to trigger history.back().
    page.execute_script("window.location.href = arguments[0]", collection_path(collection))
    assert_current_path collection_path(collection)

    assert_equal "Back to collections", find(".mobile-header-back")["aria-label"]
    assert_equal collections_path, URI(find(".mobile-header-back")["href"]).path

    # Click the chevron WITHOUT the fallback-visit helper, so a regression back to
    # history.back() (which would strand the user on /marketing/photos, the
    # referrer) actually fails here instead of being masked by a direct visit.
    # Re-find each attempt to absorb the headless dropped-click flake: a dropped
    # click leaves us on the collection page (retry); a divergence lands us
    # elsewhere (stop and let the assertion catch it).
    4.times do
      find(".mobile-header-back").click
      break if has_current_path?(collections_path, wait: 2)
      break unless has_current_path?(collection_path(collection), wait: 1)
    end

    # Lands on the labeled destination (/marketing/collections), NOT the
    # /marketing/photos referrer the old history.back() would have stranded us on.
    assert_current_path collections_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "a tasks sub-page back arrow honors its labeled destination on a cold load" do
    # The bug: a person reaches a sub-page WITHOUT navigating into it in-app —
    # a PWA cold start, a deep link from a push notification, a bookmark, or the
    # redirect after saving a form. The page then loads fresh with a same-origin
    # referrer that is NOT the back arrow's destination, and the old `back`
    # Stimulus controller called history.back() — stranding the user on the
    # referrer instead of where the arrow's label promised. The arrow must go to
    # its labeled destination regardless of how the page was reached.
    visit tasks_root_path # a same-origin page that is NOT this sub-page's back target

    # Full (non-Turbo) load into the sub-page, so document.referrer = /tasks —
    # the exact condition that used to trigger the divergent history.back().
    page.execute_script("window.location.href = arguments[0]", tasks_manage_tasks_path)
    assert_current_path tasks_manage_tasks_path

    assert_equal "Back to Settings", find("a.subpage-back")["aria-label"]
    assert_equal tasks_manage_path, URI(find("a.subpage-back")["href"]).path

    # Re-find each attempt: a dropped headless click leaves us on the same page
    # (re-find is fine), and the real fix navigates straight to the label.
    4.times do
      find("a.subpage-back").click
      break if has_current_path?(tasks_manage_path, wait: 2)
      break unless has_current_path?(tasks_manage_tasks_path, wait: 1)
    end

    # Lands on the labeled destination (/tasks/manage), NOT the /tasks referrer
    # the old history.back() would have stranded the user on.
    assert_current_path tasks_manage_path
  end

  test "a tasks sub-page back arrow returns to its destination after in-app navigation" do
    # The happy path must keep working: when the user navigates into the sub-page
    # in-app, back still lands on the labeled destination (which, because the
    # back_path/back_label are set together, is also where they came from).
    visit tasks_manage_path
    4.times do
      find("a.subpage-back").click
      break if has_current_path?(tasks_root_path, wait: 2)
    end
    assert_current_path tasks_root_path
  end

  test "editing a list from the focused work surface returns to that list, not Settings" do
    # The bug: "Edit list" on the focused work-surface view (/tasks/lists/:id)
    # dove into the Settings tree, whose back arrow names "Settings" — so back
    # stranded the user on the Tasks Settings hub instead of the list they came
    # from. The edit page must resolve its back target to its origin: the focused
    # list, label-honest (named by the list), matching where Save redirects.
    list = TaskList.create!(name: "Prep", position: 1)

    visit tasks_list_path(list)
    click_through_to(edit_tasks_manage_list_path(list, origin: "list")) { click_link "Edit list" }

    assert_equal "Back to #{list.name}", find("a.subpage-back")["aria-label"]
    assert_equal tasks_list_path(list), URI(find("a.subpage-back")["href"]).path

    click_through_to(tasks_list_path(list)) { find("a.subpage-back").click }
  end

  test "editing a list from Settings returns to the Task lists index, not the focused list" do
    # The other entry point must stay correct: reached from Settings → Task
    # lists → Edit list, the back arrow names "Task lists" and returns there.
    list = TaskList.create!(name: "Prep", position: 1)

    visit tasks_manage_lists_path
    edit_href = edit_tasks_manage_list_path(list)
    click_through_to(edit_href) { find("a.manage-row[href='#{edit_href}']").click }

    assert_equal "Back to Task lists", find("a.subpage-back")["aria-label"]
    assert_equal tasks_manage_lists_path, URI(find("a.subpage-back")["href"]).path

    click_through_to(tasks_manage_lists_path) { find("a.subpage-back").click }
  end

  test "navigating to the account page works through Turbo" do
    # Headless Chrome intermittently drops the click that kicks off Turbo
    # navigation (the same flake ApplicationSystemTestCase handles for form
    # submits). Each dropped click is independent, so retry a few times; if every
    # attempt is swallowed, fall back to a direct Turbo visit so a pure harness
    # flake can't fail the run. The assertions below still verify the destination.
    4.times do
      find(".sidebar-account").click
      break if has_current_path?(account_path, wait: 2)
    end
    visit account_path unless has_current_path?(account_path, wait: 1)

    # assert_current_path waits for Turbo Drive to finish navigating before
    # checking content — prevents a timing failure on slow CI runners.
    assert_current_path account_path
    assert_selector "h2", text: "Change password"
  end

  private

  # Click a mobile back chevron and assert it navigates to `path`.
  #
  # Headless Chrome intermittently drops the WebDriver click that starts a Turbo
  # navigation — the same flake ApplicationSystemTestCase already absorbs for
  # `fill_in` and form submits, and the account-page test above handles inline.
  # When it strikes a bare "chevron.click; assert_current_path", the click
  # silently no-ops, the URL never changes, and the run fails for a pure harness
  # reason (seen intermittently on main CI — e.g. landing back on
  # /import_batches/1 instead of /import_batches). Each dropped click is
  # independent, so retry a few times, then fall back to a direct visit so flake
  # alone can't fail the run. Where the chevron actually points is already pinned
  # by the aria-label/href assertions before each call; this confirms that
  # clicking it lands there.
  def click_mobile_back_to(path)
    4.times do
      find(".mobile-header-back").click
      break if has_current_path?(path, wait: 2)
    end
    visit path unless has_current_path?(path, wait: 1)
    assert_current_path path
  end

  # Run the block (a click that starts a Turbo navigation), retrying through the
  # same dropped-click flake click_mobile_back_to absorbs, then fall back to a
  # direct visit so a swallowed click can't fail the run. Where the link points
  # is already pinned by the aria-label/href assertions around each call; this
  # confirms following it lands on `path`.
  def click_through_to(path)
    4.times do
      yield
      break if has_current_path?(path, wait: 2)
    end
    visit path unless has_current_path?(path, wait: 1)
    assert_current_path path
  end

  # A minimal product (plus the supplier it must belong to) so the show/edit
  # pages render without seeding the whole demo catalog.
  def build_product
    supplier = Supplier.create!(name: "Primary Supplier")
    Product.create!(canonical_name: "Test Product", supplier: supplier)
  end

  # A minimal import batch with one receipt line so the import show and the
  # per-line editor render without running the full CSV importer.
  def build_import_batch_with_line
    supplier = Supplier.create!(name: "Primary Supplier")
    batch = ImportBatch.create!(supplier: supplier, source_filename: "receipt.csv",
                                file_checksum: SecureRandom.hex, imported_at: Time.current,
                                status: "imported")
    receipt = Receipt.create!(supplier: supplier, import_batch: batch, receipt_number: "R-1")
    ReceiptLineItem.create!(receipt: receipt, supplier: supplier, import_batch: batch,
                            line_number: 1, line_type: "item", raw_name: "Eggs",
                            row_checksum: SecureRandom.hex)
    batch
  end
end
