module Tasks
  # GET /tasks — the “pick a list” screen. We deliberately do NOT render
  # individual tasks here: that's the focused list view's job. This page
  # exists to (a) show totals across everything and (b) hand the user off
  # to the list they actually want to work.
  class DashboardController < ApplicationController
    def index
      operating_day = OperatingDay.new
      OccurrenceBuilder.new(operating_day: operating_day).build!(from: operating_day.today, to: operating_day.today)
      OccurrenceBuilder.new(operating_day: operating_day).build!(from: operating_day.today.beginning_of_month, to: operating_day.today.end_of_month)

      daily   = actionable_day_occurrences(operating_day)
      monthly = current_month_occurrences(operating_day)

      @metrics = TaskMetrics.new(daily: daily, monthly: monthly, operating_day: operating_day).summary.to_h_with_today_suffix
      @list_summaries = build_list_summaries(daily, monthly, operating_day)
    end

    private

    # One row per active list with any occurrences today or this month.
    # Each summary carries the counts that drive the card UI — we don't
    # send raw occurrences to the view, on purpose.
    def build_list_summaries(daily, monthly, operating_day)
      grouped_daily   = daily.group_by(&:task_list)
      grouped_monthly = monthly.group_by(&:task_list)

      lists = (grouped_daily.keys + grouped_monthly.keys).uniq
      lists.sort_by { |list| [ list.position, list.name ] }.map do |list|
        metrics = TaskMetrics.new(
          daily: grouped_daily[list] || [],
          monthly: grouped_monthly[list] || [],
          operating_day: operating_day
        ).summary

        metrics.to_h_no_suffix.merge(list: list, visible_now: list.visible_at?(operating_day.now))
      end
    end

    def actionable_day_occurrences(operating_day)
      operating_day.actionable_daily_scope
        .includes(:task_list, :active_completion)
        .reject { |occurrence| occurrence.missed?(operating_day: operating_day) }
    end

    def current_month_occurrences(operating_day)
      operating_day.actionable_monthly_scope
        .includes(:task_list, :active_completion)
        .reject(&:completed?)
        .reject { |occurrence| occurrence.missed?(operating_day: operating_day) }
    end
  end
end
