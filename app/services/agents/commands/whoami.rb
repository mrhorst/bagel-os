module Agents
  module Commands
    # Report the current authentication state. Never errors — it answers
    # "authenticated?" either way, so an agent can branch on it before acting.
    class Whoami < Command
      command "whoami"
      summary "Show who you're authenticated as (if anyone)"
      skip_auth!

      def call
        # Current.session is set by the dispatcher (from the local token in CLI
        # mode, or the bearer token over HTTP), so whoami answers the same way
        # locally and against a remote app.
        session = Current.session

        unless session
          return { authenticated: false }
        end

        user = session.user
        {
          authenticated: true,
          user: { id: user.id, name: user.name.presence, email: user.email_address, role: user.role },
          # Placeholder until multi-tenancy lands; the session is where the
          # tenant will hang.
          tenant: nil
        }
      end
    end
  end
end
