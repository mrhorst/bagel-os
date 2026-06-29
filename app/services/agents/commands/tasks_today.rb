module Agents
  module Commands
    # The staff work surface for a day: late/open/completed/missed counts plus
    # the actionable occurrences, mirroring the Tasks dashboard so an agent sees
    # exactly what staff see.
    class TasksToday < Command
      command "tasks:today"
      summary "Open/late/missed task counts and occurrences for today (or --date)"
      usage(
        "Options:",
        "  --date YYYY-MM-DD   Report for a past day instead of today",
        "  --list <name>       Only occurrences whose list name matches (case-insensitive)"
      )
      param :date, type: "date", desc: "Report for a past day instead of today"
      param :list, desc: "Only occurrences whose list name matches (case-insensitive)"

      def call
        operating_day = operating_day_for_date

        Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: operating_day.today, to: operating_day.today)
        Tasks::OccurrenceBuilder.new(operating_day: operating_day)
          .build!(from: operating_day.today.beginning_of_month, to: operating_day.today.end_of_month)

        daily = operating_day.actionable_daily_scope.includes(:task_list, :active_completion).to_a
        monthly = operating_day.actionable_monthly_scope.includes(:task_list, :active_completion).to_a

        if (list_filter = options.value("list")).present?
          needle = list_filter.downcase
          daily.select! { |o| o.snapshot_list_name.to_s.downcase.include?(needle) }
          monthly.select! { |o| o.snapshot_list_name.to_s.downcase.include?(needle) }
        end

        metrics = Tasks::TaskMetrics.new(daily: daily, monthly: monthly, operating_day: operating_day).summary

        {
          date: operating_day.today.iso8601,
          counts: metrics.to_h_no_suffix,
          daily: daily.map { |o| occurrence_json(o, operating_day) },
          monthly: monthly.map { |o| occurrence_json(o, operating_day) }
        }
      end

      private

      def occurrence_json(occurrence, operating_day)
        completion = occurrence.active_completion
        {
          id: occurrence.id,
          title: occurrence.snapshot_title,
          list: occurrence.snapshot_list_name,
          status: occurrence.status(operating_day: operating_day),
          due_at: iso(occurrence.due_at),
          requires_photo_evidence: occurrence.requires_photo_evidence,
          completed_at: iso(completion&.completed_at),
          completed_by: completion&.snapshot_staff_name
        }
      end
    end
  end
end
