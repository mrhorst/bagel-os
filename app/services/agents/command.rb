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
    # Base for every command error. Carries an optional `hint`: a short,
    # actionable next step the CLI surfaces in the error envelope so an agent
    # knows how to recover (e.g. which command to run next), not just that it
    # failed.
    class Error < StandardError
      attr_reader :hint

      def initialize(message = nil, hint: nil)
        super(message)
        @hint = hint
      end
    end

    # Raised for bad input (unknown flag value, missing argument). The CLI turns
    # this into a clean error envelope and a non-zero exit, not a stack trace.
    class UsageError < Error; end

    # Raised when a looked-up record does not exist.
    class NotFoundError < Error; end

    # Raised for credential/session failures (bad login, no active session).
    class AuthenticationError < Error; end

    # Raised when a fuzzy reference (e.g. --task "cheese") matches more than one
    # record. Carries the candidates so the CLI can hand them back and the agent
    # can ask the user which one — rather than guessing.
    class AmbiguousError < Error
      attr_reader :candidates

      def initialize(message, candidates:, hint: nil)
        super(message, hint: hint)
        @candidates = candidates
      end
    end

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

      # Declares this command changes state. Read commands omit it.
      def mutates!
        @mutates = true
      end

      def mutates?
        @mutates == true
      end

      # Opt a command out of the authentication gate (login, schema, etc.).
      # Every other command requires an authenticated session.
      def skip_auth!
        @skip_auth = true
      end

      def requires_auth?
        @skip_auth != true
      end

      # Mark a command as local-only (it manages the on-disk credential store),
      # so the HTTP API refuses it — those flows have dedicated endpoints.
      def local_only!
        @local_only = true
      end

      def local_only?
        @local_only == true
      end

      # Structured parameter metadata, surfaced by `bin/agent schema` so an
      # agent can translate transcribed intent into a valid invocation.
      #   param :query, positional: true, required: true, desc: "..."
      #   param :limit, type: "integer", desc: "..."
      def param(name, type: "string", required: false, positional: false, desc: nil)
        params << { name: name.to_s, type: type, required: required, positional: positional, desc: desc }
      end

      def params
        @params ||= []
      end

      def to_schema
        { command: command, summary: summary, mutates: mutates?, requires_auth: requires_auth?, params: params }
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

    # Load at most `limit` records and report whether more were available, by
    # asking for one extra. Lets a read command tell an agent "this is the full
    # set" vs "there's more — raise --limit" without a second COUNT query.
    # Returns [records, truncated].
    def fetch_capped(relation, limit)
      records = relation.limit(limit + 1).to_a
      [ records.first(limit), records.length > limit ]
    end

    # Standard pagination metadata for a limited read, so every list command
    # reports completeness the same way.
    def page_meta(returned:, limit:, truncated:)
      { returned: returned, limit: limit, truncated: truncated }
    end
  end
end
