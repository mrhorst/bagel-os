module Tasks
  class OccurrencesController < ApplicationController
    def show
      @occurrence = TaskOccurrence
        .includes(task_completions: [ :staff_member, :undone_by_staff_member, photo_attachment: :blob ])
        .find(params[:id])
      @active_completion = @occurrence.active_completion
      @undone_completions = @occurrence.undone_completions.includes(photo_attachment: :blob)
    end
  end
end
