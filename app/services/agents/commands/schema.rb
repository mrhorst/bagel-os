module Agents
  module Commands
    # The machine-readable command catalog. An agent reads this once to learn
    # what it can do, then maps a transcribed voice request to a command name
    # and arguments. `mutates` flags which commands change state so the agent
    # can confirm before acting (and prefer --dry-run when unsure).
    class Schema < Command
      command "schema"
      summary "Machine-readable catalog of every command (for mapping intent)"
      skip_auth!

      def call
        {
          envelope: {
            success: "stdout: { ok: true, command, generated_at, data }",
            failure: "stderr + exit 1: { ok: false, command, error: { type, message, hint? } }",
            error_types: %w[unknown_command unauthenticated usage_error not_found ambiguous error],
            error_hint: "Errors carry a `hint`: a short, actionable next step (often the command to run next). `ambiguous` errors also carry `candidates`.",
            pagination: "List commands that take --limit return `returned`, `limit`, and `truncated`. truncated=true means more rows exist — raise --limit to see them.",
            money: "decimal values are JSON strings to avoid float rounding"
          },
          global_options: [
            { name: "compact", type: "boolean", desc: "Single-line JSON" },
            { name: "dry-run", type: "boolean", desc: "On mutating commands, resolve and report what would happen without writing" }
          ],
          commands: Cli::REGISTRY.map(&:to_schema)
        }
      end
    end
  end
end
