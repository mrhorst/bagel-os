module AgentCli
  # User-facing CLI failure. The runner renders it as a JSON error envelope
  # and exits non-zero, so commands can raise it freely for bad input.
  class Error < StandardError
    attr_reader :details

    def initialize(message, details: nil)
      super(message)
      @details = details
    end
  end
end
