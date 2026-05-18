module Tasks
  class OccurrenceBuilder
    def initialize(now: Time.current)
      @now = now
    end

    def build!(from:, to:)
      from_date = from.to_date
      to_date = to.to_date

      Task.active.includes(:task_list).find_each do |task|
        occurrence_periods(task, from_date, to_date).each do |period|
          upsert_occurrence!(task, period)
        end
      end
    end

    private

    attr_reader :now

    Period = Struct.new(:kind, :starts_on, :ends_on, :due_at, :completion_window_ends_at, keyword_init: true)

    def occurrence_periods(task, from_date, to_date)
      case task.recurrence_type
      when "one_time"
        one_time_periods(task, to_date)
      when "daily"
        day_periods(task, from_date, to_date)
      when "weekly"
        weekly_periods(task, from_date, to_date)
      when "monthly"
        monthly_periods(task, from_date, to_date)
      else
        []
      end
    end

    def one_time_periods(task, to_date)
      return [] if task.one_time_on.blank? || task.one_time_on > to_date

      [
        Period.new(
          kind: "day",
          starts_on: task.one_time_on,
          ends_on: task.one_time_on,
          due_at: due_at_for(task.one_time_on, task.due_time),
          completion_window_ends_at: nil
        )
      ]
    end

    def day_periods(task, from_date, to_date)
      each_date(active_from(task, from_date), active_to(task, to_date)).map do |date|
        Period.new(
          kind: "day",
          starts_on: date,
          ends_on: date,
          due_at: due_at_for(date, task.due_time),
          completion_window_ends_at: next_midnight(date)
        )
      end
    end

    def weekly_periods(task, from_date, to_date)
      task_weekdays = task.weekday_values
      day_periods(task, from_date, to_date).select { |period| task_weekdays.include?(period.starts_on.wday) }
    end

    def monthly_periods(task, from_date, to_date)
      periods = []
      month_start = from_date.beginning_of_month
      final_month = to_date.beginning_of_month

      while month_start <= final_month
        month_end = month_start.end_of_month
        if task_active_during_period?(task, month_start, month_end)
          periods << Period.new(
            kind: "month",
            starts_on: month_start,
            ends_on: month_end,
            due_at: nil,
            completion_window_ends_at: next_midnight(month_end)
          )
        end
        month_start = month_start.next_month
      end

      periods
    end

    def upsert_occurrence!(task, period)
      occurrence = TaskOccurrence.find_or_initialize_by(
        task: task,
        period_kind: period.kind,
        period_starts_on: period.starts_on
      )
      return occurrence unless occurrence.new_record? || occurrence.refreshable?(now: now)

      occurrence.assign_attributes(
        task_list: task.task_list,
        period_ends_on: period.ends_on,
        due_at: period.due_at,
        completion_window_ends_at: period.completion_window_ends_at,
        snapshot_title: task.title,
        snapshot_instructions: task.instructions,
        snapshot_list_name: task.task_list.name,
        requires_photo_evidence: task.requires_photo_evidence,
        position: task.position
      )
      occurrence.save!
      occurrence
    end

    def active_from(task, from_date)
      [ task.starts_on, from_date ].compact.max
    end

    def active_to(task, to_date)
      [ task.ends_on, to_date ].compact.min
    end

    def task_active_during_period?(task, period_start, period_end)
      starts_on = task.starts_on || period_start
      ends_on = task.ends_on || period_end
      starts_on <= period_end && ends_on >= period_start
    end

    def each_date(from_date, to_date)
      return [] if from_date.blank? || to_date.blank? || from_date > to_date

      (from_date..to_date).to_a
    end

    def due_at_for(date, time)
      Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
    end

    def next_midnight(date)
      Time.zone.local(date.year, date.month, date.day).next_day
    end
  end
end
