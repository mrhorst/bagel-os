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
            success: "stdout: { ok: true, command, environment, generated_at, data }",
            failure: "stderr + exit 1: { ok: false, command, environment, error: { type, message, hint? } }",
            environment: "Every response names the Rails environment it ran against (development/production/...) — check it before mutating.",
            error_types: %w[unknown_command unauthenticated usage_error not_found ambiguous confirmation_required connection_error error],
            error_hint: "Errors carry a `hint`: a short, actionable next step (often the command to run next). `ambiguous` errors also carry `candidates`.",
            pagination: "List commands that take --limit return `returned`, `limit`, and `truncated`. truncated=true means more rows exist — raise --limit to see them.",
            money: "decimal values are JSON strings to avoid float rounding",
            option_values: "Negative numbers pass plainly (--par -5); any other value starting with '-' needs the = form (--notes=\"- item\")."
          },
          global_options: [
            { name: "compact", type: "boolean", desc: "Single-line JSON" },
            { name: "dry-run", type: "boolean", desc: "On mutating commands, resolve and report what would happen without writing" },
            { name: "yes", type: "boolean", desc: "Confirm a mutating command against a production app (else it fails with confirmation_required). BAGEL_AGENT_YES=1 is equivalent." }
          ],
          commands: Cli::REGISTRY.map(&:to_schema)
        }
      end
    end
  end
end
