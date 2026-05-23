class LogBookHistoryController < ApplicationController
  require_module_access :log_book

  def index
    @entries = LogBookEntry.recent_first.limit(60).includes(:log_book_responses)
  end
end
