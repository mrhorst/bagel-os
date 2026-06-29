module Agents
  # Parsed argv for one agent CLI invocation: the leftover positional tokens
  # plus a flag map. The CLI peels the command name off first, so an Options
  # only ever carries a command's own arguments.
  #
  # Supported flag forms (everything that is not a flag becomes a positional):
  #   --key value     --key=value     --flag (=> "true")     -h (alias of --help)
  class Options
    HELP_KEYS = %w[help h].freeze

    def self.parse(tokens)
      positionals = []
      flags = {}

      index = 0
      while index < tokens.length
        token = tokens[index]

        if token.start_with?("--")
          name, inline_value = token[2..].split("=", 2)
          if inline_value.nil? && next_is_value?(tokens, index)
            flags[name] = tokens[index + 1]
            index += 1
          else
            flags[name] = inline_value.nil? ? "true" : inline_value
          end
        elsif token.start_with?("-") && token.length > 1
          flags[token[1..]] = "true"
        else
          positionals << token
        end

        index += 1
      end

      new(positionals: positionals, flags: flags)
    end

    # A bare "--key" only swallows the following token as its value when that
    # token is not itself a flag, so "--missing-only --limit 5" keeps both.
    def self.next_is_value?(tokens, index)
      nxt = tokens[index + 1]
      !nxt.nil? && !nxt.start_with?("-")
    end

    def initialize(positionals:, flags:)
      @positionals = positionals
      @flags = flags
    end

    attr_reader :positionals, :flags

    def positional(index)
      @positionals[index]
    end

    def rest
      @positionals
    end

    def help?
      HELP_KEYS.any? { |key| @flags.key?(key) }
    end

    def flag?(key)
      value = @flags[key.to_s]
      value == "true" || value == true
    end

    def value(key, default = nil)
      @flags.fetch(key.to_s, default)
    end

    def integer(key, default)
      raw = @flags[key.to_s]
      return default if raw.nil?

      Integer(raw)
    rescue ArgumentError, TypeError
      raise Command::UsageError, "--#{key} must be an integer (got #{raw.inspect})"
    end
  end
end
