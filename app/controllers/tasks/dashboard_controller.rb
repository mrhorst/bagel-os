module Tasks
  # GET /tasks — the “pick a list” screen. We deliberately do NOT render
  # individual tasks here: that's the focused list view's job. This page
  # exists to (a) show totals across everything and (b) hand the user off
  # to the list they actually want to work.
  #
  # Optional ?date=YYYY-MM-DD lets the user step back through prior days
  # to review what happened. Past days render read-only: completion
  # controls (list-card taps, FAB) are suppressed, and the KPIs swap
  # "Late" for "Missed" since the day's window has closed.
  class DashboardController < ApplicationController
    PAST_DAYS_WINDOW = 90

    def index
      @selected_date  = clamp_date(parse_date(params[:date]))
      @viewing_today  = @selected_date == Date.current
      operating_day   = build_operating_day(@selected_date, @viewing_today)
      @operating_day  = operating_day

      OccurrenceBuilder.new(operating_day: operating_day).build!(from: @selected_date, to: @selected_date)
      OccurrenceBuilder.new(operating_day: operating_day).build!(from: @selected_date.beginning_of_month, to: @selected_date.end_of_month)

      daily   = day_occurrences(operating_day)
      monthly = month_occurrences(operating_day)

      @metrics = TaskMetrics.new(daily: daily, monthly: monthly, operating_day: operating_day).summary.to_h_with_today_suffix
      @list_summaries = build_list_summaries(daily, monthly, operating_day)
      @briefing = BriefingGenerator.new(operating_day: operating_day, daily: daily, monthly: monthly).find_or_generate! if @viewing_today

      @prev_date = @selected_date - 1 if @selected_date - 1 >= earliest_browsable_date
      @next_date = @selected_date + 1 if @selected_date < Date.current
    end

    private

    def parse_date(raw)
      return Date.current if raw.blank?
      Date.parse(raw)
    rescue ArgumentError, TypeError
      Date.current
    end

    def clamp_date(date)
      date = Date.current if date > Date.current
      date = earliest_browsable_date if date < earliest_browsable_date
      date
    end

    def earliest_browsable_date
      Date.current - PAST_DAYS_WINDOW
    end

    # On today, the OperatingDay reflects real "now" so KPIs distinguish
    # late vs open. On a past date we anchor it to that day's end-of-window
    # so the missed/completed split is the source of truth.
    def build_operating_day(date, viewing_today)
      return OperatingDay.new if viewing_today
      OperatingDay.new(now: Time.zone.local(date.year, date.month, date.day, 23, 59, 59))
    end

    # One row per active list with any occurrences in the selected day or
    # surrounding month. Each summary carries the counts that drive the
    # card UI — we don't send raw occurrences to the view, on purpose.
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

    def day_occurrences(operating_day)
      scope = operating_day.actionable_daily_scope.includes(:task_list, :active_completion)
        .reject { |o| o.stale_completed_carryover?(operating_day: operating_day) }
      return scope.reject { |o| o.missed?(operating_day: operating_day) } if @viewing_today
      scope
    end

    def month_occurrences(operating_day)
      scope = operating_day.actionable_monthly_scope.includes(:task_list, :active_completion)
      return scope.reject(&:completed?).reject { |o| o.missed?(operating_day: operating_day) } if @viewing_today
      scope.to_a
    end
  end
end
