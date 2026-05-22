module Tasks
  # The local calendar day used to decide when daily and weekly task
  # occurrences become missed (CONTEXT.md: Operating Day).
  #
  # Every time-of-day comparison in the Tasks Module — "is this still today?",
  # "has the completion window closed?", "what's the end-of-day moment for
  # this date?" — should route through here so the rule lives in one place.
  #
  # The MVP closes the day at local calendar midnight. The config seam exists
  # (window_end_for) but no parameter does yet; late-night kitchens add it later.
  class OperatingDay
    def self.from(time_or_nil)
      time_or_nil.is_a?(OperatingDay) ? time_or_nil : new(now: time_or_nil || Time.current)
    end

    def initialize(now: Time.current)
      @now = now
    end

    attr_reader :now

    def today
      @today ||= @now.to_date
    end

    def same_day_as?(timestamp)
      timestamp.present? && timestamp.to_date == today
    end

    def passed?(timestamp)
      timestamp.present? && @now >= timestamp
    end

    def window_end_for(date)
      Time.zone.local(date.year, date.month, date.day).next_day
    end

    def actionable_daily_scope
      TaskOccurrence
        .daily
        .where("period_starts_on = ? OR (completion_window_ends_at IS NULL AND period_starts_on <= ?)", today, today)
    end

    def actionable_monthly_scope
      TaskOccurrence.monthly.where(period_starts_on: today.beginning_of_month)
    end
  end
end
