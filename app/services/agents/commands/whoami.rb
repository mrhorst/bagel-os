module Agents
  module Commands
    # Report the current authentication state. Never errors — it answers
    # "authenticated?" either way, so an agent can branch on it before acting.
    class Whoami < Command
      command "whoami"
      summary "Show who you're authenticated as (if anyone)"
      skip_auth!

      def call
        store = CredentialStore.new
        session = Authentication.resolve_session(store.read_token)

        unless session
          return { authenticated: false, token_source: store.token_source }
        end

        user = session.user
        {
          authenticated: true,
          token_source: store.token_source,
          user: { id: user.id, name: user.name.presence, email: user.email_address, role: user.role },
          # Placeholder until multi-tenancy lands; the session is where the
          # tenant will hang.
          tenant: nil
        }
      end
    end
  end
end
