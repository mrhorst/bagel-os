module Agents
  module Commands
    # Recent task completions — what actually got done and by whom. Defaults to
    # the last 7 days to match Task History's default window.
    class TasksHistory < Command
      command "tasks:history"
      summary "Recent task completions (default last 7 days)"
      usage(
        "Options:",
        "  --days N        How many days back to include (default 7)",
        "  --limit N       Cap the number of completions returned (default 100)",
        "  --include-undone  Include undone completions (default: active only)"
      )

      def call
        days = options.integer("days", 7)
        limit = options.integer("limit", 100)
        since = days.days.ago

        scope = TaskCompletion
          .where(completed_at: since..)
          .includes(task_occurrence: :task_list)
          .order(completed_at: :desc)
          .limit(limit)
        scope = scope.where(undone_at: nil) unless options.flag?("include-undone")

        completions = scope.to_a

        {
          since: since.iso8601,
          days: days,
          count: completions.size,
          completions: completions.map { |c| completion_json(c) }
        }
      end

      private

      def completion_json(completion)
        occurrence = completion.task_occurrence
        {
          id: completion.id,
          task: occurrence&.snapshot_title,
          list: occurrence&.snapshot_list_name,
          completed_at: iso(completion.completed_at),
          completed_by: completion.snapshot_staff_name,
          notes: completion.notes.presence,
          undone: completion.undone_at.present?,
          undone_at: iso(completion.undone_at)
        }
      end
    end
  end
end
