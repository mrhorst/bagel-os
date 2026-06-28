require "application_system_test_case"

# Checking "No note today" on a Log Book section clears and disables its inputs.
# It must not DESTROY what the user already typed: an accidental tap (then
# untapping it) used to wipe the entry for good — the toggle cleared every input
# value with no way to get it back, and autosave then persisted the cleared
# state. The server already nils a section's value when "no note" is saved, so
# clearing client-side was never needed for correctness — only the data loss it
# caused was real. Toggling the box now preserves the entry so an accidental tap
# is fully recoverable by unchecking.
class LogBookNoNoteTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    LogBookSection.create!(
      title: "General Log", section_type: "long_text",
      position: 1, allow_no_note: true
    )
  end

  test "unchecking No note today restores the note it cleared" do
    visit log_book_path

    fill_in "Note", with: "Walk-in holding at 38F."

    # Checking it empties the field (so the card reads as "no note")…
    check "No note today"
    assert_equal "", find_field("Note", disabled: true).value

    # …but unchecking must bring the typed note back, not strand the user with a
    # blank field after a mis-tap.
    uncheck "No note today"
    assert_equal "Walk-in holding at 38F.", find_field("Note").value
  end
end
