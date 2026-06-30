module Agents
  module Commands
    # Revoke the stored session (delete its row) and remove the local token.
    # Always succeeds, even if there's nothing to revoke.
    class Logout < Command
      command "logout"
      summary "Revoke the stored session and clear the local token"
      skip_auth!
      local_only!

      def call
        store = CredentialStore.new
        session = Authentication.resolve_session(store.read_token)
        session&.destroy
        cleared = store.clear

        { logged_out: true, session_revoked: session.present?, token_cleared: cleared }
      end
    end
  end
end
