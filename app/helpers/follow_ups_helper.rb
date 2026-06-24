module FollowUpsHelper
  # Confirmation copy shown before reopening a resolved follow-up. Reopening
  # clears the resolution (outcome, who/when, and the note), so guard the tap
  # like every other irreversible control and name what gets lost — loudest
  # when there's a typed resolution note that would be discarded.
  def reopen_confirm_message(follow_up)
    if follow_up.resolution_note.present?
      "Reopen this follow-up? Its resolution note will be cleared."
    else
      "Reopen this follow-up? It will move back to the open list."
    end
  end
end
