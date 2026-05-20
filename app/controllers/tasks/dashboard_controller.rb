module Tasks
  class DashboardController < ApplicationController
    LIST_COOKIE = :tasks_selected_list_id
    ALL_LISTS = "all".freeze

    def index
      today = Time.zone.today
      OccurrenceBuilder.new.build!(from: today, to: today)
      OccurrenceBuilder.new.build!(from: today.beginning_of_month, to: today.end_of_month)

      @staff_members = StaffMember.active.ordered
      @current_staff_member = current_task_staff_member

      all_today   = actionable_day_occurrences(today)
      all_monthly = current_month_occurrences(today)
      @hidden_today_occurrences   = all_today.reject   { |o| o.task_list.visible_at?(Time.current) }
      @hidden_monthly_occurrences = all_monthly.reject { |o| o.task_list.visible_at?(Time.current) }
      visible_today   = all_today   - @hidden_today_occurrences
      visible_monthly = all_monthly - @hidden_monthly_occurrences

      # The user's effective universe — every list with any occurrence today
      # or this month, whether currently visible by display window or not.
      universe = visible_today + @hidden_today_occurrences + visible_monthly + @hidden_monthly_occurrences
      @all_task_lists = universe.map(&:task_list).uniq.sort_by { |list| [ list.position, list.name ] }

      @selected_task_list = resolve_selected_list(@all_task_lists)
      @show_list_picker   = should_show_picker?

      if @selected_task_list.is_a?(TaskList)
        visible_today   = visible_today.select   { |o| o.task_list_id == @selected_task_list.id }
        visible_monthly = visible_monthly.select { |o| o.task_list_id == @selected_task_list.id }
      end

      @today_occurrences   = visible_today
      @monthly_occurrences = visible_monthly
      @grouped_today_occurrences   = grouped_occurrences(@today_occurrences)
      @grouped_monthly_occurrences = grouped_occurrences(@monthly_occurrences)
      @metrics = board_metrics(@today_occurrences, @monthly_occurrences, @hidden_today_occurrences + @hidden_monthly_occurrences)

      # Per-list open counts power the picker's "X open" labels.
      @list_open_counts = (all_today + all_monthly)
        .group_by(&:task_list_id)
        .transform_values { |occs| occs.count { |o| !o.completed? && !o.missed? } }

      persist_list_selection
    end

    private

    # Resolution order: explicit ?list= param → cookie → nil (picker).
    # `?list=all` opts in to the combined view; we honor and remember it.
    def resolve_selected_list(lists)
      raw = params[:list].presence || cookies[LIST_COOKIE]
      return nil if raw.blank?
      return :all if raw.to_s == ALL_LISTS

      lists.find { |l| l.id.to_s == raw.to_s }
    end

    def should_show_picker?
      return false if @selected_task_list == :all
      return false if @selected_task_list.is_a?(TaskList)
      @all_task_lists.size >= 2
    end

    # Only persist when the user made an explicit choice this request.
    def persist_list_selection
      return unless params.key?(:list)

      value =
        case @selected_task_list
        when :all then ALL_LISTS
        when TaskList then @selected_task_list.id.to_s
        end

      if value
        cookies[LIST_COOKIE] = { value: value, expires: 90.days.from_now }
      else
        cookies.delete(LIST_COOKIE)
      end
    end

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

    def board_metrics(today_occurrences, monthly_occurrences, hidden_today_occurrences)
      statuses = today_occurrences.map { |occurrence| occurrence.status }
      {
        open_today: statuses.count("open"),
        late_today: statuses.count("late"),
        completed_today: statuses.count("completed"),
        open_this_month: monthly_occurrences.size,
        hidden_today: hidden_today_occurrences.size
      }
    end

    def sort_key_for(occurrence)
      rank = { "late" => 0, "open" => 1, "completed" => 2 }.fetch(occurrence.status, 3)
      [ rank, occurrence.due_at || Time.zone.local(9999, 1, 1), occurrence.position, occurrence.snapshot_title ]
    end
  end
end
