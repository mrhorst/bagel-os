module Agents
  # POST /agent — run one agent command remotely.
  #
  # Body: { "argv": ["tasks:create", "--list", "Closing", "--title", "Lock up", "--due-time", "22:00"] }
  # Auth: Authorization: Bearer <token>
  #
  # Returns the same envelope the CLI prints, so a remote agent gets identical
  # output to a local run. The shared Dispatcher enforces auth and the
  # production-write guardrail.
  class CommandsController < ApiController
    # Generous for a working agent (~2/s sustained) but stops a runaway loop
    # from hammering the app.
    rate_limit to: 120, within: 1.minute, with: -> { render_rate_limited }

    def create
      argv = Array(params[:argv]).map(&:to_s)
      result = Dispatcher.new(session: current_agent_session, context: :api).call(argv)
      render json: result.payload, status: http_status(result)
    end

    private

    def http_status(result)
      return :ok if result.ok?

      case result.error_type
      when "unauthenticated" then :unauthorized
      when "not_found", "unknown_command" then :not_found
      when "confirmation_required" then :conflict
      when "ambiguous", "usage_error" then :unprocessable_entity
      else :internal_server_error
      end
    end
  end
end
