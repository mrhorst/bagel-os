class FollowUpNotesController < ApplicationController
  require_module_access :follow_ups

  def create
    follow_up = FollowUp.find(params[:follow_up_id])
    note      = follow_up.notes.build(body: params.require(:follow_up_note).permit(:body)[:body], author: Current.user)

    if note.save
      redirect_to follow_up_path(follow_up), notice: "Note added."
    else
      redirect_to follow_up_path(follow_up), alert: note.errors.full_messages.to_sentence
    end
  end
end
