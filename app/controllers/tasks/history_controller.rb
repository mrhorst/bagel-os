module Tasks
  class HistoryController < ApplicationController
    def index
      @from_date = parse_date(params[:from], default: 6.days.ago.to_date)
      @to_date = parse_date(params[:to], default: Time.zone.today)
      @status = params[:status].presence
      @task_list_id = params[:task_list_id].presence
      @task_lists = TaskList.ordered

      OccurrenceBuilder.new.build!(from: @from_date, to: @to_date)
      @occurrences = filtered_occurrences
    end

    private

    def filtered_occurrences
      scope = TaskOccurrence
        .includes(:task_list, :active_completion)
        .for_period_range(@from_date, @to_date)
      scope = scope.where(task_list_id: @task_list_id) if @task_list_id.present?

      scope
        .to_a
        .select { |occurrence| @status.blank? || occurrence.status == @status }
        .sort_by { |occurrence| [ occurrence.period_starts_on, occurrence.due_at || occurrence.period_ends_on.to_time, occurrence.position ] }
        .reverse
    end

    def parse_date(value, default:)
      Date.iso8601(value)
    rescue ArgumentError, TypeError
      default
    end
  end
end
