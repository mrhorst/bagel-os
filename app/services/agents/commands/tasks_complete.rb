module Agents
  module Commands
    # Complete a task occurrence — the canonical voice action ("I finished
    # sweeping the front"). Resolves the occurrence (by id or fuzzy title) and
    # the attributed user, then runs the same Tasks::CompleteOccurrence service
    # the UI uses, so every guard (already-completed, missed, photo-required)
    # still applies.
    class TasksComplete < Command
      command "tasks:complete"
      summary "Complete a task occurrence (by --occurrence id or --task name)"
      mutates!
      usage(
        "Usage: bin/agent tasks:complete --task \"sweep front\" --user maria@example.com",
        "",
        "Options:",
        "  --occurrence N   Target by occurrence id (exact)",
        "  --task <name>    Target by fuzzy title among today's actionable tasks",
        "  --user <ref>     Attribute to this user (email, name, or id) — required",
        "  --notes <text>   Optional completion note",
        "  --date YYYY-MM-DD  Operate against a past day (rare)",
        "  --dry-run        Resolve and report what would happen, without writing"
      )
      param :occurrence, type: "integer", desc: "Target by occurrence id (exact)"
      param :task, desc: "Target by fuzzy title among today's actionable tasks"
      param :user, required: true, desc: "Attribute to this user (email, name, or id)"
      param :notes, desc: "Optional completion note"
      param :date, type: "date", desc: "Operate against a past day (rare)"
      param :"dry-run", type: "boolean", desc: "Resolve and report what would happen, without writing"

      def call
        operating_day = operating_day_for_date
        occurrence = TaskTargeting.resolve_occurrence(options, operating_day)
        user = TaskTargeting.resolve_user(options)

        guard_completable!(occurrence)

        if options.flag?("dry-run")
          return {
            dry_run: true,
            would: "complete",
            occurrence: TaskTargeting.occurrence_summary(occurrence, operating_day),
            as: { id: user.id, name: user.name.presence, email: user.email_address }
          }
        end

        completion = Tasks::CompleteOccurrence.new(operating_day: operating_day).call(
          occurrence: occurrence,
          user: user,
          notes: options.value("notes")
        )

        {
          completed: true,
          occurrence: TaskTargeting.occurrence_summary(occurrence.reload, operating_day),
          completion: {
            id: completion.id,
            completed_at: iso(completion.completed_at),
            completed_by: completion.snapshot_staff_name,
            notes: completion.notes.presence
          }
        }
      rescue ActiveRecord::RecordInvalid, ArgumentError => e
        raise UsageError, e.message
      end

      private

      # Photo-required tasks can't be completed from a voice/CLI flow (no image
      # to attach) — fail with a clear, actionable message rather than a
      # validation stack trace.
      def guard_completable!(occurrence)
        if occurrence.requires_photo_evidence?
          raise UsageError, "#{occurrence.snapshot_title.inspect} requires photo evidence, which can't be attached from the CLI. Complete it in the app."
        end
      end
    end
  end
end
