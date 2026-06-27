class FollowUpNotesController < ApplicationController
  require_module_access :follow_ups

  def create
    @follow_up = FollowUp.includes(notes: :author).find(params[:follow_up_id])
    # Build standalone (not via the association) so a rejected note doesn't get
    # appended to the loaded notes thread we re-render below.
    @note      = FollowUpNote.new(follow_up: @follow_up, body: note_params[:body], author: Current.user)

    if @note.save
      redirect_to follow_up_path(@follow_up), notice: "Note added."
    else
      # Re-render the detail page with the typed note and its error in place,
      # rather than redirecting — a redirect would drop what the user wrote and
      # detach the error from the form. Mirrors the spawn-task form on this same
      # page (FollowUpsController#spawn_task), which already recovers in place.
      @note_body   = note_params[:body]
      @note_errors = @note.errors
      render "follow_ups/show", status: :unprocessable_entity
    end
  end

  private

  def note_params
    params.require(:follow_up_note).permit(:body)
  end
end
