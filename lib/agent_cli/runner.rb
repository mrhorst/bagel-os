module AgentCli
  # Entry point for bin/bagel — the agent-facing CLI for tasks, follow-ups,
  # and the log book. Dispatches "<resource> <action> [options]" to a command
  # class and prints a JSON envelope on stdout:
  #
  #   {"ok": true, "data": {...}}                       exit 0
  #   {"ok": false, "error": "...", "details": [...]}   exit 1
  #
  # Help output (--help at any level) is plain text, exit 0.
  class Runner
    def self.resources
      {
        "tasks" => TasksCommand,
        "task-lists" => TaskListsCommand,
        "follow-ups" => FollowUpsCommand,
        "log-book" => LogBookCommand
      }
    end

    def self.run(argv, out: $stdout)
      argv = argv.dup
      resource = argv.shift

      if resource.nil? || %w[-h --help help].include?(resource)
        out.puts usage
        return 0
      end

      command = resources[resource]
      unless command
        return fail_with(out, "Unknown resource #{resource.inspect}.",
          details: [ "Expected one of: #{resources.keys.join(', ')}" ])
      end

      data = command.new.call(argv)
      out.puts JSON.pretty_generate({ ok: true, data: data })
      0
    rescue HelpRequested => help
      out.puts help.message
      0
    rescue Error => error
      fail_with(out, error.message, details: error.details)
    rescue ActiveRecord::RecordNotFound => error
      fail_with(out, error.message)
    rescue ActiveRecord::RecordInvalid => error
      fail_with(out, "Validation failed", details: error.record.errors.full_messages)
    rescue ActiveRecord::RecordNotDestroyed => error
      fail_with(out, error.message, details: error.record&.errors&.full_messages)
    rescue OptionParser::ParseError => error
      fail_with(out, error.message)
    end

    def self.fail_with(out, message, details: nil)
      payload = { ok: false, error: message }
      payload[:details] = details if details.present?
      out.puts JSON.pretty_generate(payload)
      1
    end
    private_class_method :fail_with

    def self.usage
      <<~USAGE
        bin/bagel — agent CLI for Bagel OS tasks, follow-ups, and the log book.

        Usage: bin/bagel <resource> <action> [options]

        Resources:
          tasks         List, create, update, archive recurring/one-time tasks
          task-lists    List and create the task lists tasks live on
          follow-ups    List, create, update, resolve, reopen, annotate follow-ups
          log-book      Read the daily log book and write today's responses

        Every action prints a JSON envelope: {"ok": true, "data": ...} on
        success, {"ok": false, "error": ..., "details": [...]} on failure
        (exit code 1).

        Run `bin/bagel <resource> --help` for the actions and options of each
        resource.
      USAGE
    end
  end
end
