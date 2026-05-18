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
end
