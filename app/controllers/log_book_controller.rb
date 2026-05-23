class LogBookController < ApplicationController
  require_module_access :log_book

  def index
    @today = Time.zone.today
  end
end
