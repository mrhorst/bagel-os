module TasksHelper
  def task_status_badge(occurrence)
    status = occurrence.status
    badge_class =
      case status
      when "completed" then "badge-ok"
      when "late" then "badge-warning"
      when "missed" then "badge-danger"
      else ""
      end

    tag.span(status.humanize, class: [ "badge", badge_class ])
  end

  # Status left-rule for a history row. Mirrors the badge's severity so the
  # whole row — not just the small far-left badge — carries the signal, using
  # the same 2px inset left rule as .task-row-late / .warning-row elsewhere.
  # Only the attention states get a rule; completed/open stay neutral so the
  # rule reads as "needs a look", never a painted-per-status background.
  def task_status_row_class(occurrence)
    case occurrence.status
    when "late" then "warning-row"
    when "missed" then "danger-row"
    else ""
    end
  end

  # Under a labelled column or a <dt>Due</dt>, the leading "Due " restates the
  # label on every row — noise the History table and the occurrence detail don't
  # need. Pass prefix: false there; the Tasks dashboard row (an inline value with
  # no adjacent "Due" label) keeps the default prefix so the time stays legible.
  def task_due_label(occurrence, prefix: true)
    if occurrence.period_kind == "month"
      "This month"
    elsif occurrence.due_at.present?
      time = occurrence.due_at.strftime("%-I:%M %p")
      prefix ? "Due #{time}" : time
    else
      prefix ? "Due today" : "Today"
    end
  end

  def task_list_display_window_label(task_list)
    return "Always visible" unless task_list.display_window?

    start_label = task_time_label(task_list.display_start_time)
    end_label = task_time_label(task_list.display_end_time)

    if task_list.display_start_time.present? && task_list.display_end_time.present?
      "Visible #{start_label} - #{end_label}"
    elsif task_list.display_start_time.present?
      "Visible after #{start_label}"
    else
      "Visible until #{end_label}"
    end
  end

  def task_completion_summary(completion)
    return nil if completion.blank?

    "Completed by #{completion.snapshot_staff_name} at #{completion.completed_at.strftime("%-I:%M %p")}"
  end

  def task_period_label(occurrence)
    if occurrence.period_kind == "month"
      "#{occurrence.period_starts_on.strftime("%b %-d")} - #{occurrence.period_ends_on.strftime("%b %-d, %Y")}"
    else
      occurrence.period_starts_on.strftime("%b %-d, %Y")
    end
  end

  def task_recurrence_label(task)
    case task.recurrence_type
    when "one_time"
      "One-time on #{task.one_time_on&.strftime("%b %-d, %Y")} at #{task_time_label(task.due_time)}"
    when "daily"
      "Daily at #{task_time_label(task.due_time)}"
    when "weekly"
      "Weekly on #{task_weekday_label(task)} at #{task_time_label(task.due_time)}"
    when "monthly"
      "Any time this month"
    else
      task.recurrence_type.to_s.humanize
    end
  end

  def task_weekday_label(task)
    days = task.weekday_values.map { |weekday| Date::ABBR_DAYNAMES.fetch(weekday) }
    return "selected weekdays" if days.empty?

    days.to_sentence
  end

  def task_time_label(time)
    return "no time" if time.blank?

    time.strftime("%-I:%M %p")
  end
end
