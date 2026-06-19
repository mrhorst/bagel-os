module Notifications
  # Sweeps for task occurrences that have slipped past their due time but can
  # still be completed (status "late"), and pushes one collapsing notification
  # per user so the floor clears them before the window closes at end of day.
  #
  # Time-based, not event-based: nothing writes to the DB at the moment a task
  # goes late, so this runs on a schedule (see config/recurring.yml) rather than
  # a callback. Each occurrence is announced at most once — `late_notified_at`
  # is stamped after sending — and a single per-user `tag` collapses the bubble,
  # so a manager gets a couple of these per shift, not a firehose.
  class LateTasksJob < ApplicationJob
    queue_as :background

    def perform(now: Time.current)
      return unless WebPushConfig.configured?
      return if Notifications::QuietHours.active?(now)

      operating_day = Tasks::OperatingDay.new(now: now)
      occurrences = newly_late_occurrences(operating_day)
      return if occurrences.empty?

      deliver(occurrences)
      TaskOccurrence.where(id: occurrences.map(&:id)).update_all(late_notified_at: now)
    end

    private

    def newly_late_occurrences(operating_day)
      operating_day
        .actionable_daily_scope
        .where(late_notified_at: nil)
        .includes(:task_list, :active_completion)
        .select { |occurrence| occurrence.late?(operating_day: operating_day) && occurrence.task_list.visible_at?(operating_day.now) }
    end

    def deliver(occurrences)
      title, body, url, tag = digest(occurrences)
      Notifications::Audience.for_module(:tasks).find_each do |user|
        user.push_subscriptions.notify_all(title: title, body: body, url: url, tag: tag)
      end
    end

    # One late task gets a specific, deep-linked notification; several collapse
    # into a digest pointing at the tasks dashboard.
    def digest(occurrences)
      if occurrences.one?
        occurrence = occurrences.first
        [
          "#{occurrence.snapshot_title} is late",
          "#{occurrence.snapshot_title} in #{occurrence.snapshot_list_name} was due at #{occurrence.due_at.strftime('%-l:%M %p')}.",
          routes.tasks_occurrence_path(occurrence),
          "tasks-late"
        ]
      else
        [
          "#{occurrences.size} tasks are late",
          "#{late_task_list(occurrences)} are past due. Tap to clear them before end of day.",
          routes.tasks_root_path,
          "tasks-late"
        ]
      end
    end

    # "Prep Mix and Sanitize Slicer" for two; "Prep Mix, Sanitize Slicer and 3
    # more" once the list would get unwieldy.
    def late_task_list(occurrences)
      names = occurrences.map(&:snapshot_title)
      return names.to_sentence if names.size <= 3

      "#{names.first(2).join(', ')} and #{names.size - 2} more"
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
