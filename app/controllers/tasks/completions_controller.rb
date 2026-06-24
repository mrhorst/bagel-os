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

      LiveUpdates.task_state_changed!
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

      LiveUpdates.task_state_changed!
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
            row_stream(occurrence),
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
        format.html { change_redirect(occurrence.id, notice: notice) }
      end
    end

    # A completed monthly occurrence is filtered out of the focused list's
    # "This month" section (TaskListsController#month_occurrences_for rejects
    # completed) and never reappears until a new month — and the task_row
    # partial only renders a completion state for daily rows (`!monthly`).
    # Replacing a just-completed monthly row would therefore render a
    # contradictory, still-tappable "Mark complete" circle beside its
    # "Completed" badge (tapping it again raises "already completed"). Match
    # the list's own filter — and the live-update morph — by REMOVING the row
    # so the instant feedback agrees with the page's steady state. Daily rows
    # keep the in-place replace: they show the completed circle and the morph
    # relocates them into the Completed disclosure.
    def row_stream(occurrence)
      if occurrence.period_kind == "month" && occurrence.completed?
        turbo_stream.remove(helpers.dom_id(occurrence))
      else
        turbo_stream.replace(
          helpers.dom_id(occurrence),
          partial: "tasks/dashboard/task_row",
          locals: { occurrence: occurrence, monthly: occurrence.period_kind == "month" }
        )
      end
    end

    # The occurrence detail page's complete/undo forms submit a full-page
    # request carrying ?back (the list the user was working from). Preserve it
    # on the redirect so the reloaded occurrence page's back arrow keeps naming
    # that list instead of decaying to the dashboard. Other callers (the list's
    # own no-JS completion circle) carry no ?back and fall back to redirect_back,
    # returning to the list as before.
    def change_redirect(occurrence_id, **flash)
      if params[:back].present?
        redirect_to tasks_occurrence_path(occurrence_id, back: params[:back]), **flash
      else
        redirect_back fallback_location: tasks_root_path, **flash
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
        format.turbo_stream { change_redirect(params[:occurrence_id], alert: error.message) }
        format.html         { change_redirect(params[:occurrence_id], alert: error.message) }
      end
    end
  end
end
