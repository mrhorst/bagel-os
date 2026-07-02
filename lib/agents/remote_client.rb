# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "openssl"
require "fileutils"
require "io/console"

module Agents
  # The remote transport for `bin/agent`, used when BAGEL_API_URL is set. Pure
  # stdlib on purpose: it must run with no Rails boot, no gems, and no checkout
  # near the agent — just a token and a URL. It forwards commands to the app's
  # /agent endpoint and prints the same envelope a local run would.
  #
  # login/logout are handled here (they own the on-disk token) by calling the
  # /agent/session endpoints; every other command is forwarded verbatim.
  class RemoteClient
    DEFAULT_CONFIG_DIR = File.expand_path("~/.config/bagel-os")

    # Raised when the app can't be reached at all (DNS, refused, TLS, timeout).
    class ConnectionError < StandardError; end

    def self.run(argv, api_url: ENV["BAGEL_API_URL"], out: $stdout, err: $stderr, transport: nil)
      new(api_url: api_url, out: out, err: err, transport: transport).run(argv)
    end

    def initialize(api_url:, out: $stdout, err: $stderr, transport: nil)
      @api_url = api_url.to_s.sub(%r{/+\z}, "")
      @out = out
      @err = err
      @transport = transport || method(:http_request)
    end

    # Returns a process exit status (0 success, 1 failure).
    def run(argv)
      # Only a leading help token means "show the client help" — `X --help`
      # must forward so the server can answer with that command's usage, and a
      # value that happens to contain "-h" must not trigger help.
      return print_help if argv.empty? || %w[-h --help].include?(argv.first)

      case argv.first
      when "help"
        # `help X` → the same per-command usage a local run prints, via the API.
        argv[1] ? forward([ argv[1], "--help" ]) : print_help
      when "login"  then login(argv[1..])
      when "logout" then logout(argv[1..])
      else forward(argv)
      end
    rescue ConnectionError => e
      emit_error("connection_error", e.message, "Check BAGEL_API_URL (#{@api_url.inspect}) and that the app is reachable.")
    end

    private

    # ── command paths ──────────────────────────────────────────────────────

    def forward(argv)
      _status, body = api_call("POST", "agent", { "argv" => argv }, token: read_token)
      finish(body, compact: argv.include?("--compact"))
    end

    def login(args)
      email = flag(args, "email")
      return emit_error("usage_error", "Provide --email", "Usage: agent login --email <you>") if email.nil? || email.empty?

      password = flag(args, "password") || env(:password) || prompt_password
      return emit_error("usage_error", "Password required.", "Pass --password, set BAGEL_AGENT_PASSWORD, or run in a terminal.") if password.nil? || password.empty?

      _status, body = api_call("POST", "agent/session", { "email" => email, "password" => password })
      return finish(body) unless body["ok"]

      write_credentials(token: body["token"], email: email)
      data = {
        "authenticated" => true,
        "environment" => body["environment"],
        "user" => body["user"],
        "credentials_path" => credentials_path
      }
      data["token"] = body["token"] if flag?(args, "print-token")
      emit({ "ok" => true, "command" => "login", "environment" => body["environment"], "data" => data }, compact: flag?(args, "compact"))
      0
    end

    def logout(args)
      token = read_token
      body = token ? api_call("DELETE", "agent/session", nil, token: token).last : {}
      cleared = clear_credentials
      emit({
        "ok" => true,
        "command" => "logout",
        "data" => { "logged_out" => true, "session_revoked" => body["session_revoked"] == true, "token_cleared" => cleared }
      }, compact: flag?(args, "compact"))
      0
    end

    # ── output ─────────────────────────────────────────────────────────────

    # Print an envelope and return the matching exit code (0 ok / 1 not).
    def finish(body, compact: false)
      if body["ok"]
        emit(body, compact: compact)
        0
      else
        @err.puts(JSON.pretty_generate(body))
        1
      end
    end

    def emit(payload, compact:)
      @out.puts(compact ? JSON.generate(payload) : JSON.pretty_generate(payload))
    end

    def emit_error(type, message, hint = nil)
      error = { "type" => type, "message" => message }
      error["hint"] = hint if hint
      @err.puts(JSON.pretty_generate({ "ok" => false, "error" => error }))
      1
    end

    def print_help
      @out.puts(<<~TEXT)
        Bagel OS agent CLI — remote mode (BAGEL_API_URL=#{@api_url.inspect}).

        Usage: agent <command> [options]
          agent login --email <you>      Authenticate against the remote app
          agent logout                   Revoke the session and clear the token
          agent schema                   Machine-readable catalog of commands
          agent whoami                   Who am I authenticated as

        Commands run against the remote app. Mutations on a production app
        require --yes. Run `agent schema` for the full catalog.
      TEXT
      0
    end

    # ── HTTP ───────────────────────────────────────────────────────────────

    # Returns [status_integer, parsed_body_hash].
    def api_call(method, path, payload, token: nil)
      headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
      headers["Authorization"] = "Bearer #{token}" if token
      status, raw = @transport.call(method, "#{@api_url}/#{path}", headers, payload && JSON.generate(payload))
      [ status, parse(raw) ]
    end

    def parse(raw)
      return {} if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      { "ok" => false, "error" => { "type" => "bad_response", "message" => raw.to_s[0, 200] } }
    end

    def http_request(method, url, headers, body)
      uri = URI.parse(url)
      klass = { "POST" => Net::HTTP::Post, "DELETE" => Net::HTTP::Delete }.fetch(method)
      request = klass.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = body if body

      # Explicit timeouts so a wedged server fails fast as a connection_error
      # instead of hanging the agent on Net::HTTP's 60s defaults.
      timeout = Integer(ENV.fetch("BAGEL_AGENT_HTTP_TIMEOUT", 10))
      response = Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout, read_timeout: timeout, write_timeout: timeout
      ) do |http|
        http.request(request)
      end
      [ response.code.to_i, response.body.to_s ]
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, Timeout::Error, URI::InvalidURIError => e
      raise ConnectionError, "#{e.class}: #{e.message}"
    end

    # ── credential file (same format/location as Agents::CredentialStore) ────

    def config_dir
      ENV["BAGEL_OS_CONFIG_DIR"].to_s.empty? ? DEFAULT_CONFIG_DIR : ENV["BAGEL_OS_CONFIG_DIR"]
    end

    def credentials_path
      File.join(config_dir, "credentials.json")
    end

    def read_token
      return ENV["BAGEL_AGENT_TOKEN"] unless ENV["BAGEL_AGENT_TOKEN"].to_s.empty?
      return nil unless File.exist?(credentials_path)

      JSON.parse(File.read(credentials_path))["token"]
    rescue JSON::ParserError
      nil
    end

    def write_credentials(token:, email:)
      FileUtils.mkdir_p(config_dir, mode: 0o700)
      # Owner-only from the first byte (no write-then-chmod window).
      File.open(credentials_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(JSON.pretty_generate("token" => token, "email" => email))
      end
      File.chmod(0o600, credentials_path)
    end

    def clear_credentials
      return false unless File.exist?(credentials_path)

      File.delete(credentials_path)
      true
    end

    # ── tiny option helpers (no Rails Options class available here) ──────────

    def flag(args, name)
      args.each_with_index do |token, index|
        return token.split("=", 2)[1] if token.start_with?("--#{name}=")
        return args[index + 1] if token == "--#{name}"
      end
      nil
    end

    def flag?(args, name)
      args.include?("--#{name}")
    end

    def env(name)
      value = ENV["BAGEL_AGENT_#{name.to_s.upcase}"]
      value unless value.to_s.empty?
    end

    def prompt_password
      return nil unless $stdin.tty?

      $stdin.getpass("Password: ").to_s
    end
  end
end
