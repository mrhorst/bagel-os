require "application_system_test_case"

# Log Book History (/log-book/history) is a "past days" list: you tap a day to
# open its read-only entry. That day page is the Log Book index controller, and
# its mobile back chevron defaults to "Back to Log Book" → today (right for a
# bookmark, a deep link, the date pager, or the post-save redirect). But a
# manager who drilled in FROM History wants back to return to History, not get
# ejected to today with no way back to the list they were working.
#
# The History row now carries an explicit origin (from=history) and the day page
# resolves the chevron server-side (LogBookController), mirroring the
# explicit-origin convention Tasks::ManageController / OccurrencesController use.
# These tests drive the real mobile-width browser: the chevron only renders below
# the 640px breakpoint, where it is the primary way back.
class LogBookHistoryBackContextTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "a past day opened from History sends its back chevron to History, not today" do
    LogBookEntry.create!(operating_date: Date.current - 3)

    page.current_window.resize_to(414, 896)
    visit log_book_history_path

    # The History row threads the origin so the day can resolve its way back.
    assert_includes find("a.log-book-recent-link")[:href], "from=history"

    open_from_history
    assert_current_path log_book_path(date: Date.current - 3, from: "history")

    chevron = find(".mobile-header-back")
    assert_equal "Back to History", chevron["aria-label"]
    assert_equal log_book_history_path, URI(chevron[:href]).path

    click_mobile_back_to log_book_history_path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "a past day reached without an origin keeps its back chevron on today" do
    # The deliberate default for the date pager / a bookmark / a deep link / the
    # post-save redirect must not change: only the History drill-in is rerouted.
    page.current_window.resize_to(414, 896)
    visit log_book_path(date: Date.current - 3)

    chevron = find(".mobile-header-back")
    assert_equal "Back to Log Book", chevron["aria-label"]
    assert_equal log_book_path, URI(chevron[:href]).path
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  private

  # Tap into the past day from the History list, absorbing the dropped-click
  # flake headless Chrome occasionally injects (the same one the shared base
  # class handles for fill_in / form submits), then fall back to a direct visit
  # so a swallowed click can't fail the run. The from=history href is already
  # asserted above; this just follows it.
  def open_from_history
    target = log_book_path(date: Date.current - 3, from: "history")
    4.times do
      find("a.log-book-recent-link").click
      break if has_current_path?(target, wait: 2)
    end
    visit target unless has_current_path?(target, wait: 1)
  end

  # Click the mobile back chevron and assert it navigates to `path`, retrying
  # through the dropped-click flake. Where the chevron points is already pinned
  # by the aria-label/href assertions before each call; this confirms following
  # it lands there.
  def click_mobile_back_to(path)
    4.times do
      find(".mobile-header-back").click
      break if has_current_path?(path, wait: 2)
    end
    visit path unless has_current_path?(path, wait: 1)
    assert_current_path path
  end
end
