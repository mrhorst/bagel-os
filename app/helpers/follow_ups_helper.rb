module FollowUpsHelper
  # Status-badge classes for a follow-up's urgency. Mirrors the card's 2px
  # left-rule convention (.follow-up-card-urgent = danger/red,
  # .follow-up-card-important = warn/amber, normal = no rule) so the badge
  # actually encodes severity. Previously every urgency hard-coded
  # `badge badge-warning`, which painted the neutral "Normal" tier with a
  # warning amber and left an Urgent item indistinguishable from an Important
  # one.
  def follow_up_urgency_badge_class(urgency)
    case urgency
    when "urgent"    then "badge badge-danger"
    when "important" then "badge badge-warning"
    else                  "badge"
    end
  end

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
