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

        # The env var and the credentials file can hold tokens for different
        # sessions; revoke both so logout never strands a live session while
        # deleting the only copy of its token.
        tokens = [ ENV[CredentialStore::ENV_TOKEN], store.file_token ].compact.uniq
        sessions = tokens.filter_map { |token| Authentication.resolve_session(token) }.uniq
        sessions.each(&:destroy)
        cleared = store.clear

        { logged_out: true, session_revoked: sessions.any?, sessions_revoked: sessions.size, token_cleared: cleared }
      end
    end
  end
end
