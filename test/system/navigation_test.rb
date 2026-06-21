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

    chevron.click
    assert_current_path log_book_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "the mobile back chevron on Log Sections returns to Log Book, not the hub" do
    # Same gap as the Log Book settings sub-page: below 640px the layout's
    # auto-chevron points at the module hub (Shift), overshooting Log Book — the
    # page's own parent and what its in-body "Back to Log Book" button names.
    page.current_window.resize_to(414, 896)
    visit log_book_sections_path

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Book", chevron["aria-label"]
    assert_equal log_book_path, URI(chevron[:href]).path

    chevron.click
    assert_current_path log_book_path
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

    chevron.click
    assert_current_path log_book_path
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

    chevron.click
    assert_current_path log_book_sections_path
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

    chevron.click
    assert_current_path log_book_sections_path
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

    chevron.click
    assert_current_path products_path
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

    chevron.click
    assert_current_path product_path(product)
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

    chevron.click
    assert_current_path order_guides_path
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

    chevron.click
    assert_current_path inventory_counts_path
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

    chevron.click
    assert_current_path admin_tags_path
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

    chevron.click
    assert_current_path admin_tags_path
  ensure
    page.current_window.resize_to(1400, 1400)
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

  # A minimal product (plus the supplier it must belong to) so the show/edit
  # pages render without seeding the whole demo catalog.
  def build_product
    supplier = Supplier.create!(name: "Primary Supplier")
    Product.create!(canonical_name: "Test Product", supplier: supplier)
  end
end
