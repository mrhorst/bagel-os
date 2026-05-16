module ApplicationHelper
  def app_branding
    @app_branding ||= AppBranding.current
  end
end
