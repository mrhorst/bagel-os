class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_paper_trail_whodunnit

  # PaperTrail's PaperTrail::Controller#user_for_paper_trail expects this.
  # The id is stringified into versions.whodunnit; cast back to int on read.
  def user_for_paper_trail
    Current.user&.id
  end
end
