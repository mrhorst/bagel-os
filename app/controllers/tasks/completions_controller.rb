module Tasks
  class CompletionsController < ApplicationController
    def create
      occurrence = TaskOccurrence.find(params[:occurrence_id])
      completion = CompleteOccurrence.new.call(
        occurrence: occurrence,
        staff_member: require_current_task_staff_member!,
        notes: params[:notes],
        photo: params[:photo]
      )

      redirect_to tasks_root_path, notice: "Completed #{completion.task_occurrence.snapshot_title}."
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      redirect_to tasks_root_path, alert: error.message
    end

    def destroy
      occurrence = TaskOccurrence.find(params[:occurrence_id])
      completion = occurrence.active_completion || raise(ArgumentError, "Task is not currently completed.")
      raise ArgumentError, "Confirm undo before updating task history." unless params[:confirm_undo] == "1"

      UndoCompletion.new.call(
        completion: completion,
        staff_member: require_current_task_staff_member!,
        note: params[:undone_note]
      )

      redirect_to tasks_root_path, notice: "Undid #{occurrence.snapshot_title}."
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      redirect_to tasks_root_path, alert: error.message
    end
  end
end
