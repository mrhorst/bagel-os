module Agents
  module Commands
    # Undo today's completion of a task occurrence ("scratch that, I didn't
    # actually finish it"). Mirrors Tasks::UndoCompletion, including its
    # same-operating-day guard.
    class TasksUndo < Command
      command "tasks:undo"
      summary "Undo today's completion of a task occurrence"
      mutates!
      usage(
        "Usage: bin/agent tasks:undo --task \"sweep front\" --user maria@example.com",
        "",
        "Options:",
        "  --occurrence N   Target by occurrence id (exact)",
        "  --task <name>    Target by fuzzy title among today's actionable tasks",
        "  --user <ref>     Who is undoing it (email, name, or id) — required",
        "  --note <text>    Optional reason for the undo",
        "  --dry-run        Resolve and report what would happen, without writing"
      )
      param :occurrence, type: "integer", desc: "Target by occurrence id (exact)"
      param :task, desc: "Target by fuzzy title among today's actionable tasks"
      param :user, required: true, desc: "Who is undoing it (email, name, or id)"
      param :note, desc: "Optional reason for the undo"
      param :"dry-run", type: "boolean", desc: "Resolve and report what would happen, without writing"

      def call
        operating_day = Tasks::OperatingDay.new
        occurrence = TaskTargeting.resolve_occurrence(options, operating_day)
        user = TaskTargeting.resolve_user(options)

        completion = occurrence.active_completion
        raise UsageError, "#{occurrence.snapshot_title.inspect} is not currently completed." if completion.blank?

        if options.flag?("dry-run")
          return {
            dry_run: true,
            would: "undo",
            occurrence: TaskTargeting.occurrence_summary(occurrence, operating_day),
            completion_id: completion.id
          }
        end

        Tasks::UndoCompletion.new(operating_day: operating_day).call(
          completion: completion,
          user: user,
          note: options.value("note")
        )

        {
          undone: true,
          occurrence: TaskTargeting.occurrence_summary(occurrence.reload, operating_day)
        }
      rescue ActiveRecord::RecordInvalid, ArgumentError => e
        raise UsageError, e.message
      end
    end
  end
end
