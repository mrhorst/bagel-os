require "application_system_test_case"

# Flagging a Log Book section for follow-up reveals an urgency segmented row;
# unflagging hides it and resets the choice to "normal". That reset must not
# DESTROY a chosen urgency: an accidental untap (then re-tapping the flag) used
# to wipe the selection for good — unflagging reset the radios to "normal" with
# no way to recover the prior choice, and the form's autosave then persisted the
# downgrade. Re-flagging now restores whatever urgency was chosen, so an
# accidental tap is fully recoverable — the same non-destructive guarantee the
# "No note today" toggle (same controller) already provides for typed values.
class LogBookFollowUpUrgencyTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    LogBookSection.create!(
      title: "General Log", section_type: "long_text",
      position: 1, allow_follow_up: true
    )
  end

  test "re-flagging follow-up restores the urgency it reset on unflag" do
    visit log_book_path

    check "Flag for follow-up"
    # The segmented radio input is visually hidden (opacity:0), so drive it via
    # its label the way a person taps the segment.
    choose "Urgent", allow_label_click: true
    assert find("input[type=radio][value='urgent']", visible: :all).checked?

    # Unflagging hides the urgency row and resets the visible choice to normal…
    uncheck "Flag for follow-up"

    # …but re-flagging must bring the chosen urgency back, not strand the user on
    # "normal" after a mis-tap.
    check "Flag for follow-up"
    assert find("input[type=radio][value='urgent']", visible: :all).checked?,
           "re-flagging should restore the previously chosen 'urgent' urgency, not reset it to normal"
  end
end
