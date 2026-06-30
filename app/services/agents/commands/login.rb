require "io/console"

module Agents
  module Commands
    # Authenticate and store a session token so later commands run as you.
    # The password comes from --password, the BAGEL_AGENT_PASSWORD env var, or
    # an interactive prompt (preferred — keeps it out of shell history/process
    # listings).
    class Login < Command
      command "login"
      summary "Authenticate and store a session token"
      skip_auth!
      local_only!
      usage(
        "Usage: bin/agent login --email you@example.com",
        "",
        "Options:",
        "  --email <email>     Account email (required)",
        "  --password <pw>     Password (else BAGEL_AGENT_PASSWORD, else prompt)",
        "  --print-token       Also print the token (for setting BAGEL_AGENT_TOKEN)"
      )
      param :email, required: true, desc: "Account email"
      param :password, desc: "Password (else BAGEL_AGENT_PASSWORD env, else prompt)"
      param :"print-token", type: "boolean", desc: "Also print the token for env-based use"

      def call
        email = options.value("email")
        raise UsageError, "Provide --email" if email.blank?

        password = resolve_password
        session, token = Authentication.login(email: email, password: password)

        path = CredentialStore.new.write(token: token, email: email)
        result = {
          authenticated: true,
          user: { id: session.user.id, name: session.user.name.presence, email: session.user.email_address },
          credentials_path: path
        }
        result[:token] = token if options.flag?("print-token")
        result
      end

      private

      def resolve_password
        explicit = options.value("password").presence || ENV["BAGEL_AGENT_PASSWORD"].presence
        return explicit if explicit
        raise UsageError, "Provide --password, set BAGEL_AGENT_PASSWORD, or run in a terminal to be prompted." unless $stdin.tty?

        $stdin.getpass("Password: ").to_s
      end
    end
  end
end
