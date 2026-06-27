module Agents
  # Base class for every agent CLI command.
  #
  # A command declares its registry name, a one-line summary, and optional usage
  # lines, then implements #call returning a plain Hash/Array that is JSON-safe.
  # The CLI wraps that payload in the standard envelope and prints it — commands
  # never touch stdout themselves, so their output stays composable.
  #
  # Commands are READ-ONLY by design (see docs/agents/agent-cli.md). Keep them
  # side-effect free so an agent can call them freely while reasoning.
  class Command
    # Raised for bad input (unknown flag value, missing argument). The CLI turns
    # this into a clean error envelope and a non-zero exit, not a stack trace.
    class UsageError < StandardError; end

    # Raised when a looked-up record does not exist.
    class NotFoundError < StandardError; end

    class << self
      def command(name = nil)
        @command = name if name
        @command
      end

      def summary(text = nil)
        @summary = text if text
        @summary
      end

      def usage(*lines)
        @usage = lines unless lines.empty?
        @usage || []
      end
    end

    def initialize(options)
      @options = options
    end

    attr_reader :options

    def call
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    private

    # Parse an optional --date YYYY-MM-DD into an OperatingDay anchored to that
    # day's end-of-window, or "now" when absent. Mirrors the Tasks dashboard so
    # the late/missed split matches what staff see in the UI.
    def operating_day_for_date
      raw = options.value("date")
      return Tasks::OperatingDay.new if raw.blank?

      date = Date.parse(raw)
      return Tasks::OperatingDay.new if date == Date.current

      Tasks::OperatingDay.new(now: Time.zone.local(date.year, date.month, date.day, 23, 59, 59))
    rescue ArgumentError
      raise UsageError, "--date must be YYYY-MM-DD (got #{raw.inspect})"
    end

    # Money/decimals serialize to strings so JSON consumers never inherit float
    # rounding error on prices. nil passes through.
    def money(value)
      return nil if value.nil?

      BigDecimal(value.to_s).to_s("F")
    end

    def iso(time)
      time&.iso8601
    end
  end
end
