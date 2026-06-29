module Agents
  # Entry point for `bin/agent` — a read-only, JSON-emitting command line for
  # AI agents (and curious humans) to query Bagel OS domain data without
  # scraping HTML. Each subcommand maps to an Agents::Command subclass.
  #
  #   bin/agent help
  #   bin/agent tasks:today
  #   bin/agent price:product "house blend" --compact
  #
  # Output is a single JSON document on stdout. Success:
  #   { "ok": true, "command": "tasks:today", "generated_at": "...", "data": {...} }
  # Failure (also exit status 1):
  #   { "ok": false, "command": "...", "error": { "type": "...", "message": "..." } }
  class Cli
    # Registered in the order they should appear in `help`. Listing the classes
    # here (rather than scanning) keeps the surface explicit and lets Zeitwerk
    # autoload each command on reference.
    REGISTRY = [
      Commands::Login,
      Commands::Logout,
      Commands::Whoami,
      Commands::Schema,
      Commands::TasksToday,
      Commands::TasksHistory,
      Commands::TasksLists,
      Commands::InventoryGaps,
      Commands::InventorySections,
      Commands::PriceSpikes,
      Commands::PriceProduct,
      Commands::ProductsSearch,
      Commands::ReviewsPending,
      Commands::PurchasingDashboard,
      Commands::StaffList,
      Commands::TasksCreateList,
      Commands::TasksCreate,
      Commands::InventoryAddItem,
      Commands::TasksComplete,
      Commands::TasksUndo
    ].freeze

    def self.run(argv, out: $stdout, err: $stderr)
      new(out: out, err: err).run(argv)
    end

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    # Returns a process exit status (0 success, 1 failure).
    def run(argv)
      tokens = argv.dup
      name = tokens.shift

      if name.nil? || %w[-h --help].include?(name) || name == "help"
        # `help <command>` shows that command's usage; bare `help` lists all.
        target = lookup(tokens.first)
        return print_command_help(target) && 0 if target

        return print_help && 0
      end

      command_class = lookup(name)
      unless command_class
        return fail!(name, "unknown_command", "Unknown command #{name.inspect}.", hint: "Run `bin/agent help` for the command list, or `bin/agent schema` for the machine-readable catalog.")
      end

      options = Options.parse(tokens)
      return print_command_help(command_class) && 0 if options.help?

      if command_class.requires_auth? && !authenticate!
        return fail!(name, "unauthenticated", "Not authenticated.", hint: "Run `bin/agent login --email <you>` first, or set BAGEL_AGENT_TOKEN.")
      end

      data = command_class.new(options).call
      emit(envelope(name, data), compact: options.flag?("compact"))
      0
    rescue Command::AmbiguousError => e
      fail!(name, "ambiguous", e.message, hint: e.hint || "Re-run with the exact id from `candidates`.", details: { candidates: e.candidates })
    rescue Command::UsageError => e
      fail!(name, "usage_error", e.message, hint: e.hint)
    rescue Command::AuthenticationError => e
      fail!(name, "unauthenticated", e.message, hint: e.hint || "Run `bin/agent login --email <you>`.")
    rescue Command::NotFoundError => e
      fail!(name, "not_found", e.message, hint: e.hint)
    rescue => e
      fail!(name, "error", "#{e.class}: #{e.message}")
    end

    private

    # Resolve the stored token to a live Session and bind it to Current for the
    # command run (the seam tenancy will extend). Returns false when there's no
    # valid session.
    def authenticate!
      session = Authentication.resolve_session(CredentialStore.new.read_token)
      return false unless session

      Current.session = session
      true
    end

    def lookup(name)
      return nil if name.nil?

      REGISTRY.find { |klass| klass.command == name }
    end

    def envelope(name, data)
      {
        ok: true,
        command: name,
        generated_at: Time.current.iso8601,
        data: data
      }
    end

    def emit(payload, compact:)
      json = compact ? JSON.generate(payload) : JSON.pretty_generate(payload)
      @out.puts(json)
    end

    def fail!(name, type, message, hint: nil, details: nil)
      error = { type: type, message: message }
      error[:hint] = hint if hint.present?
      error.merge!(details) if details
      payload = { ok: false, command: name, error: error }
      @err.puts(JSON.pretty_generate(payload))
      1
    end

    def print_help
      lines = [ "Bagel OS agent CLI — read-only JSON access to domain data.", "", "Usage: bin/agent <command> [options]", "", "Commands:" ]
      width = REGISTRY.map { |klass| klass.command.length }.max
      REGISTRY.each do |klass|
        lines << format("  %-#{width}s  %s", klass.command, klass.summary)
      end
      lines += [ "  %-#{width}s  %s" % [ "help", "Show this help (or `help <command>` for details)" ] ]
      lines += [ "", "Global options:", "  --compact    Emit single-line JSON", "  --help, -h   Show command usage" ]
      @out.puts(lines.join("\n"))
      true
    end

    def print_command_help(command_class)
      lines = [ "#{command_class.command} — #{command_class.summary}" ]
      unless command_class.usage.empty?
        lines << ""
        lines += command_class.usage
      end
      @out.puts(lines.join("\n"))
      true
    end
  end
end
