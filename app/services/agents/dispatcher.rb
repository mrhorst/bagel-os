module Agents
  # Transport-agnostic core of the agent CLI: given an argv and a resolved
  # session, it parses, enforces auth + the production-write guardrail, runs the
  # command, and returns a structured envelope. Both the local CLI (`Agents::Cli`)
  # and the HTTP API (`Agents::CommandsController`) call this, so command
  # behavior can't drift between "run it here" and "post it to prod".
  class Dispatcher
    # ok? plus the error type, so callers map to an exit code (CLI) or an HTTP
    # status (API) without re-parsing the payload.
    Result = Struct.new(:ok, :error_type, :payload, keyword_init: true) do
      def ok?
        ok
      end
    end

    def initialize(session: nil, context: :cli, production: Rails.env.production?)
      @session = session
      @context = context
      @production = production
    end

    def call(argv)
      tokens = argv.dup
      name = tokens.shift
      return failure(name, "usage_error", "No command given.", hint: "Run `bin/agent schema` to list commands.") if name.nil?

      command_class = lookup(name)
      return failure(name, "unknown_command", "Unknown command #{name.inspect}.", hint: "Run `bin/agent schema` for the catalog.") unless command_class

      if @context == :api && command_class.local_only?
        return failure(name, "usage_error", "#{name} is only available locally.", hint: "Use the /agent/session endpoint to authenticate over HTTP.")
      end

      options = Options.parse(tokens)
      Current.session = @session

      if command_class.requires_auth? && @session.nil?
        return failure(name, "unauthenticated", "Not authenticated.", hint: "Run `bin/agent login` first, or set BAGEL_AGENT_TOKEN.")
      end

      if command_class.mutates? && @production && !confirmed?(options)
        return failure(name, "confirmation_required",
          "Refusing to run a write against production without confirmation.",
          hint: "Re-run with --yes (or set BAGEL_AGENT_YES=1) to proceed.")
      end

      success(name, command_class.new(options).call)
    rescue Command::AmbiguousError => e
      failure(name, "ambiguous", e.message, hint: e.hint || "Re-run with the exact id from `candidates`.", details: { candidates: e.candidates })
    rescue Command::UsageError => e
      failure(name, "usage_error", e.message, hint: e.hint)
    rescue Command::AuthenticationError => e
      failure(name, "unauthenticated", e.message, hint: e.hint)
    rescue Command::NotFoundError => e
      failure(name, "not_found", e.message, hint: e.hint)
    rescue => e
      failure(name, "error", "#{e.class}: #{e.message}")
    end

    private

    def lookup(name)
      Cli::REGISTRY.find { |klass| klass.command == name }
    end

    def confirmed?(options)
      options.flag?("yes") || ENV["BAGEL_AGENT_YES"] == "1"
    end

    def success(name, data)
      Result.new(ok: true, payload: {
        ok: true,
        command: name,
        environment: Rails.env.to_s,
        generated_at: Time.current.iso8601,
        data: data
      })
    end

    def failure(name, type, message, hint: nil, details: nil)
      error = { type: type, message: message }
      error[:hint] = hint if hint.present?
      error.merge!(details) if details

      Result.new(ok: false, error_type: type, payload: {
        ok: false,
        command: name,
        environment: Rails.env.to_s,
        error: error
      })
    end
  end
end
