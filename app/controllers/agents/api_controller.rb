module Agents
  # Base for the agent HTTP API. ActionController::API rather than
  # ApplicationController: no cookie session, no CSRF, no browser gate, none of
  # the HTML middleware — this is a token-authenticated JSON endpoint for
  # agents, not a browser surface.
  class ApiController < ActionController::API
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

    def render_rate_limited
      render json: {
        ok: false,
        error: { type: "rate_limited", message: "Too many requests. Try again shortly." }
      }, status: :too_many_requests
    end
  end
end
