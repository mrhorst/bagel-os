module Agents
  # Authentication for the CLI, built on the same primitives as the web app:
  # User.authenticate_by verifies credentials and a Session row is the unit of
  # access. The web app puts the session id in a signed cookie; the CLI signs
  # it into a bearer token instead (Rails' message verifier), so the stored
  # token can't be forged without secret_key_base and a session is revoked by
  # deleting its row (logout) — no schema change needed.
  #
  # This is also the seam for future multi-tenancy: when tenants land, the
  # resolved session carries the tenant and callers set Current.tenant here.
  module Authentication
    VERIFIER_PURPOSE = "agent_cli_session".freeze

    # Tokens expire so a leaked one has a bounded life even if logout is never
    # run (the Session row is still the revocation lever before that). Override
    # with BAGEL_AGENT_TOKEN_TTL_DAYS; 0 disables expiry.
    DEFAULT_TTL_DAYS = 30

    module_function

    # Verify credentials, open a Session, and return [session, token].
    # Raises Command::AuthenticationError on bad credentials.
    def login(email:, password:, user_agent: "bagel-os-agent-cli")
      user = User.authenticate_by(email_address: email.to_s, password: password.to_s)
      raise Command::AuthenticationError, "Invalid email or password." if user.nil?

      session = user.sessions.create!(user_agent: user_agent, ip_address: nil)
      [ session, token_for(session) ]
    end

    # A signed, tamper-proof bearer token for a session.
    def token_for(session)
      verifier.generate({ "sid" => session.id }, purpose: VERIFIER_PURPOSE, expires_in: token_ttl)
    end

    # Resolve a token back to its live Session, or nil if the token is blank,
    # forged, expired, or its session has been revoked.
    def resolve_session(token)
      return nil if token.blank?

      payload = verifier.verify(token, purpose: VERIFIER_PURPOSE)
      Session.find_by(id: payload["sid"])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def token_ttl
      days = Integer(ENV.fetch("BAGEL_AGENT_TOKEN_TTL_DAYS", DEFAULT_TTL_DAYS))
      days.positive? ? days.days : nil
    end

    def verifier
      Rails.application.message_verifier(VERIFIER_PURPOSE)
    end
  end
end
