class LogBookResponsesController < ApplicationController
  before_action :require_admin!

  def resolve
    response = LogBookResponse.find(params[:id])
    response.resolve!(user: Current.user)
    redirect_back fallback_location: log_book_path, notice: "Follow-up resolved."
  end
end
