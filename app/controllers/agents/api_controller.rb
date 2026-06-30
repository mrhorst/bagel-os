module Agents
  # Base for the agent HTTP API. Deliberately NOT ApplicationController: no
  # cookie session, no CSRF token, no modern-browser gate — this is a
  # token-authenticated JSON endpoint for agents, not a browser surface.
  class ApiController < ActionController::Base
    skip_forgery_protection

    private

    # The bearer token from `Authorization: Bearer <token>`, or nil.
    def bearer_token
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip.presence
    end

    def current_agent_session
      @current_agent_session ||= Agents::Authentication.resolve_session(bearer_token)
    end
  end
end
