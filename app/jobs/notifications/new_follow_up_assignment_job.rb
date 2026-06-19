module Notifications
  # Pushes the assignee the moment a follow-up is assigned to them.
  #
  # Assignment is a discrete, user-initiated change with a single known
  # recipient, so it's fired from a FollowUp callback (edge-triggered) and run
  # here so a slow push service never blocks the request. The per-follow-up
  # `tag` means re-assigning the same item replaces its bubble instead of
  # stacking. Quiet hours intentionally do not apply — this is rare and the
  # recipient is expecting it.
  class NewFollowUpAssignmentJob < ApplicationJob
    queue_as :background

    def perform(follow_up_id)
      return unless WebPushConfig.configured?

      follow_up = FollowUp.find_by(id: follow_up_id)
      return if follow_up.nil?

      assignee = follow_up.assigned_to
      return if assignee.nil? || !assignee.can_access?(:follow_ups)

      assignee.push_subscriptions.notify_all(
        title: "Follow-up assigned to you",
        body: body_for(follow_up),
        url: Rails.application.routes.url_helpers.follow_up_path(follow_up),
        tag: "follow-up-#{follow_up.id}"
      )
    end

    private

    def body_for(follow_up)
      if follow_up.urgency == "normal"
        "#{follow_up.title}."
      else
        "#{follow_up.title} — marked #{follow_up.urgency}."
      end
    end
  end
end
