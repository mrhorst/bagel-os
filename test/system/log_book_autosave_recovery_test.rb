require "application_system_test_case"

# The Log Book daily entry autosaves and, on a failed save, keeps a local copy.
# That copy used to be write-only (never restored) and self-destructing (the
# first keystroke after a failed-save reload overwrote it) — so a manager on
# flaky wifi could permanently lose a compliance entry they were told was safe
# (#216). The kept copy must now be recoverable via an explicit "Restore unsaved
# work" control, and must survive a keystroke until it is restored or a save
# succeeds.
class LogBookAutosaveRecoveryTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    LogBookSection.create!(title: "General Log", section_type: "long_text", position: 1)
  end

  test "a failed save keeps the work recoverable via Restore" do
    visit log_book_path

    force_failed_saves
    fill_in "Note", with: "Fix door gasket on the walk-in."
    assert_text "Couldn't save — copy kept in this browser"

    # Return to the page (fetch works again on a fresh load).
    visit log_book_path

    # The recovery control is offered and the field is empty until the user pulls
    # the draft back — it is never auto-applied.
    assert_selector ".log-book-draft-recovery:not([hidden])"
    assert_equal "", find_field("Note").value

    click_on "Restore unsaved work"
    assert_equal "Fix door gasket on the walk-in.", find_field("Note").value
  end

  test "typing after a failed-save reload does not destroy the kept draft" do
    visit log_book_path

    force_failed_saves
    fill_in "Note", with: "Sanitizer buckets refilled at 2pm."
    assert_text "Couldn't save — copy kept in this browser"

    visit log_book_path
    assert_selector ".log-book-draft-recovery:not([hidden])"

    # Keep saves failing, then "start typing to retry" — the old footgun. The
    # kept draft must survive, so Restore still recovers the original work.
    force_failed_saves
    fill_in "Note", with: "x"

    click_on "Restore unsaved work"
    assert_equal "Sanitizer buckets refilled at 2pm.", find_field("Note").value
  end

  private

  # Make every autosave fetch reject, simulating a dropped network save.
  def force_failed_saves
    page.execute_script(<<~JS)
      window.fetch = () => Promise.reject(new Error("offline"));
    JS
  end
end
