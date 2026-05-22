module Tasks
  class CompletionsController < ApplicationController
    def create
      occurrence = TaskOccurrence.find(params[:occurrence_id])
      CompleteOccurrence.new.call(
        occurrence: occurrence,
        user: Current.user,
        notes: params[:notes],
        photo: params[:photo]
      )

      respond_with_updated_row(occurrence.reload, notice: "Completed #{occurrence.snapshot_title}.")
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      respond_with_error(error)
    end

    def destroy
      occurrence = TaskOccurrence.find(params[:occurrence_id])
      completion = occurrence.active_completion || raise(ArgumentError, "Task is not currently completed.")
      raise ArgumentError, "Confirm undo before updating task history." unless params[:confirm_undo] == "1"

      UndoCompletion.new.call(
        completion: completion,
        user: Current.user,
        note: params[:undone_note]
      )

      respond_with_updated_row(occurrence.reload, notice: "Undid #{occurrence.snapshot_title}.")
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      respond_with_error(error)
    end

    private

    # On Turbo requests we swap the single row in place AND refresh the KPI
    # squares that belong to this task's list — so Late/Open/Done tick over
    # without a full reload. Plain-HTML clients (curl, no-JS) still get the
    # redirect.
    def respond_with_updated_row(occurrence, notice:)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              helpers.dom_id(occurrence),
              partial: "tasks/dashboard/task_row",
              locals: { occurrence: occurrence, monthly: occurrence.period_kind == "month" }
            ),
            turbo_stream.replace(
              "task_list_kpis_#{occurrence.task_list_id}",
              partial: "tasks/kpi_squares",
              locals: {
                metrics: list_metrics_for(occurrence.task_list),
                dom_id:  "task_list_kpis_#{occurrence.task_list_id}"
              }
            )
          ]
        end
        format.html { redirect_back fallback_location: tasks_root_path, notice: notice }
      end
    end

    # Recompute today's counters for one list. Turbo silently no-ops if the
    # KPI target isn't on the page (e.g. completing from the detail page),
    # so it's safe to always send.
    def list_metrics_for(task_list)
      operating_day = OperatingDay.new
      daily = operating_day.actionable_daily_scope
        .where(task_list_id: task_list.id)
        .includes(:active_completion)
        .reject { |occurrence| occurrence.missed?(operating_day: operating_day) }

      TaskMetrics.new(daily: daily, operating_day: operating_day).summary.to_h_with_today_suffix
    end

    def respond_with_error(error)
      respond_to do |format|
        format.turbo_stream { redirect_back fallback_location: tasks_root_path, alert: error.message }
        format.html         { redirect_back fallback_location: tasks_root_path, alert: error.message }
      end
    end
  end
end
