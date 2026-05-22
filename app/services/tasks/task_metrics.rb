module Tasks
  # Late / Open / Completed / Monthly-Open counts for a collection of
  # TaskOccurrences. Callers do their own grouping (per task list, across
  # all lists, etc.) and hand the resulting slices to this class.
  class TaskMetrics
    Summary = Data.define(:late, :open, :completed, :monthly_open) do
      def to_h_with_today_suffix
        { late_today: late, open_today: open, completed_today: completed, open_this_month: monthly_open }
      end

      def to_h_no_suffix
        { late: late, open: open, completed: completed, monthly_open: monthly_open }
      end
    end

    def initialize(daily: [], monthly: [], operating_day: OperatingDay.new)
      @daily = daily
      @monthly = monthly
      @operating_day = operating_day
    end

    def summary
      counts = Hash.new(0)
      @daily.each { |occurrence| counts[occurrence.status(operating_day: @operating_day)] += 1 }

      Summary.new(
        late: counts["late"],
        open: counts["open"],
        completed: counts["completed"],
        monthly_open: @monthly.size
      )
    end
  end
end
