module Tasks
  class DashboardController < ApplicationController
    def index
      today = Time.zone.today
      OccurrenceBuilder.new.build!(from: today, to: today)
      OccurrenceBuilder.new.build!(from: today.beginning_of_month, to: today.end_of_month)

      @staff_members = StaffMember.active.ordered
      @current_staff_member = current_task_staff_member
      @today_occurrences = actionable_day_occurrences(today)
      @monthly_occurrences = current_month_occurrences(today)
      @grouped_today_occurrences = grouped_occurrences(@today_occurrences)
      @grouped_monthly_occurrences = grouped_occurrences(@monthly_occurrences)
      @metrics = board_metrics(@today_occurrences, @monthly_occurrences)
    end

    private

    def actionable_day_occurrences(today)
      TaskOccurrence
        .daily
        .includes(:task_list, :active_completion)
        .where("period_starts_on = ? OR (completion_window_ends_at IS NULL AND period_starts_on <= ?)", today, today)
        .reject { |occurrence| occurrence.missed? }
        .sort_by { |occurrence| sort_key_for(occurrence) }
    end

    def current_month_occurrences(today)
      TaskOccurrence
        .monthly
        .includes(:task_list, :active_completion)
        .where(period_starts_on: today.beginning_of_month)
        .reject(&:completed?)
        .reject(&:missed?)
        .sort_by { |occurrence| [ occurrence.task_list.position, occurrence.position, occurrence.snapshot_title ] }
    end

    def grouped_occurrences(occurrences)
      occurrences.group_by(&:task_list).sort_by { |task_list, _items| [ task_list.position, task_list.name ] }
    end

    def board_metrics(today_occurrences, monthly_occurrences)
      statuses = today_occurrences.map { |occurrence| occurrence.status }
      {
        open_today: statuses.count("open"),
        late_today: statuses.count("late"),
        completed_today: statuses.count("completed"),
        open_this_month: monthly_occurrences.size
      }
    end

    def sort_key_for(occurrence)
      rank = { "late" => 0, "open" => 1, "completed" => 2 }.fetch(occurrence.status, 3)
      [ rank, occurrence.due_at || Time.zone.local(9999, 1, 1), occurrence.position, occurrence.snapshot_title ]
    end
  end
end
