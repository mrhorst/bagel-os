module AgentCli
  # Raised when the caller asked for help text; the runner prints the
  # message verbatim (plain text, not JSON) and exits 0.
  class HelpRequested < StandardError; end
end
