module Agents
  # The agent auth endpoints — the HTTP equivalent of `bin/agent login/logout`.
  # Kept separate from the command endpoint because credentials (login) and
  # session revocation (logout) aren't regular commands: login returns a token
  # the client stores, and neither touches a local file.
  #
  #   POST   /agent/session   { email, password }  -> { ok, token, user, environment }
  #   DELETE /agent/session   (Bearer token)       -> { ok, logged_out }
  class SessionsController < ApiController
    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { render json: { ok: false, error: { type: "rate_limited", message: "Too many login attempts. Try again later." } }, status: :too_many_requests }

    def create
      session, token = Authentication.login(
        email: params[:email].to_s,
        password: params[:password].to_s,
        user_agent: request.user_agent
      )
      render json: {
        ok: true,
        environment: Rails.env.to_s,
        token: token,
        user: user_json(session.user)
      }
    rescue Command::AuthenticationError => e
      render json: { ok: false, error: { type: "unauthenticated", message: e.message } }, status: :unauthorized
    end

    def destroy
      session = current_agent_session
      session&.destroy
      render json: { ok: true, environment: Rails.env.to_s, logged_out: true, session_revoked: session.present? }
    end

    private

    def user_json(user)
      { id: user.id, name: user.name.presence, email: user.email_address, role: user.role }
    end
  end
end
