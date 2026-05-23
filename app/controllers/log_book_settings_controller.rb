class LogBookSettingsController < ApplicationController
  require_module_access :log_book

  def index
    @section_count   = LogBookSection.active.count
    @archived_count  = LogBookSection.where(active: false).count
  end
end
