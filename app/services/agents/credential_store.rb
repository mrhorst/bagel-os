require "fileutils"

module Agents
  # Where the CLI's bearer token lives between invocations. Deliberately OUTSIDE
  # the repo (the user's home dir by default) so checking out the project grants
  # no data access on its own — you authenticate first. This matters now and
  # more so once the app is multi-tenant.
  #
  # Token resolution order:
  #   1. BAGEL_AGENT_TOKEN env var  — for agents/automation, no file needed
  #   2. the credentials file       — written by `bin/agent login`
  class CredentialStore
    ENV_TOKEN = "BAGEL_AGENT_TOKEN".freeze
    ENV_CONFIG_DIR = "BAGEL_OS_CONFIG_DIR".freeze

    def config_dir
      ENV[ENV_CONFIG_DIR].presence || File.expand_path("~/.config/bagel-os")
    end

    def credentials_path
      File.join(config_dir, "credentials.json")
    end

    # The token to authenticate with, and where it came from (:env / :file / nil).
    def read_token
      return ENV[ENV_TOKEN] if ENV[ENV_TOKEN].present?

      file_data["token"].presence
    end

    def token_source
      return :env if ENV[ENV_TOKEN].present?
      return :file if file_data["token"].present?

      nil
    end

    def stored_email
      file_data["email"]
    end

    # Persist the token with owner-only permissions.
    def write(token:, email:)
      FileUtils.mkdir_p(config_dir, mode: 0o700)
      File.write(credentials_path, JSON.pretty_generate("token" => token, "email" => email))
      File.chmod(0o600, credentials_path)
      credentials_path
    end

    # Remove the credentials file. Returns true if one was present.
    def clear
      return false unless File.exist?(credentials_path)

      File.delete(credentials_path)
      true
    end

    private

    def file_data
      return {} unless File.exist?(credentials_path)

      JSON.parse(File.read(credentials_path))
    rescue JSON::ParserError
      {}
    end
  end
end
