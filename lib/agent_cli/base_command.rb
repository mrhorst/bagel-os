require "optparse"

module AgentCli
  # Shared plumbing for CLI commands: action dispatch, option parsing, and
  # lookups that need agent-friendly error messages. Subclasses declare
  # `actions` (a name => method symbol map) and `usage` text.
  class BaseCommand
    def call(argv)
      action = argv.shift
      raise HelpRequested, usage if action.nil? || %w[-h --help help].include?(action)

      handler = self.class.actions[action]
      unless handler
        raise Error.new("Unknown action #{action.inspect}.",
          details: [ "Expected one of: #{self.class.actions.keys.join(', ')}" ])
      end

      send(handler, argv)
    end

    private

    # Builds an OptionParser, wires up --help, parses argv in place (options
    # may appear before or after positional args), and returns the leftover
    # positional arguments.
    def parse_options(argv, banner)
      parser = OptionParser.new
      parser.banner = banner
      yield parser if block_given?
      parser.on("-h", "--help", "Show this help") { raise HelpRequested, parser.to_s }
      parser.parse!(argv)
      argv
    end

    def require_id!(argv, usage_hint)
      id = argv.shift
      raise Error, "Missing ID argument. Usage: #{usage_hint}" if id.blank?
      id
    end

    def find_user!(email)
      return nil if email.blank?

      User.find_by(email_address: email.strip.downcase) ||
        raise(Error, "No user with email #{email.inspect}.")
    end

    def parse_date!(value, flag)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      raise Error, "#{flag} must be an ISO date (YYYY-MM-DD), got #{value.inspect}."
    end

    def parse_time_of_day!(value, flag)
      raise Error, "#{flag} must look like HH:MM (24h), got #{value.inspect}." unless value.to_s.match?(/\A\d{1,2}:\d{2}\z/)
      value
    end

    def require_inclusion!(value, allowed, flag)
      return value if allowed.include?(value)
      raise Error, "#{flag} must be one of: #{allowed.join(', ')} (got #{value.inspect})."
    end
  end
end
