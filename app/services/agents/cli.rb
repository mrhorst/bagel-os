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

      # Parse once: `<command> --help` prints usage without running anything,
      # and the same parse decides --compact for the output below.
      command_class = lookup(name)
      options = Options.parse(tokens)
      return print_command_help(command_class) && 0 if command_class && options.help?

      # Everything else runs through the shared dispatcher, with the session
      # resolved from the locally stored token.
      session = Authentication.resolve_session(CredentialStore.new.read_token)
      result = Dispatcher.new(session: session, context: :cli).call(argv)

      if result.ok?
        emit(result.payload, compact: options.flag?("compact"))
        0
      else
        @err.puts(JSON.pretty_generate(result.payload))
        1
      end
    end

    private

    def lookup(name)
      return nil if name.nil?

      REGISTRY.find { |klass| klass.command == name }
    end

    def emit(payload, compact:)
      json = compact ? JSON.generate(payload) : JSON.pretty_generate(payload)
      @out.puts(json)
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
