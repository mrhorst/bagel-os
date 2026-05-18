module TasksHelper
  def task_status_badge(occurrence)
    status = occurrence.status
    badge_class =
      case status
      when "completed" then "badge-ok"
      when "late", "missed" then "badge-warning"
      else ""
      end

    tag.span(status.humanize, class: [ "badge", badge_class ])
  end

  def task_due_label(occurrence)
    if occurrence.period_kind == "month"
      "This month"
    elsif occurrence.due_at.present?
      "Due #{occurrence.due_at.strftime("%-I:%M %p")}"
    else
      "Due today"
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
