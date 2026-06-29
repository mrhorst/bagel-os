module Agents
  module Commands
    # The task lists you can file tasks into. An agent reads this to resolve
    # "add it to the closing list" before tasks:create.
    class TasksLists < Command
      command "tasks:lists"
      summary "Task lists, with how many active tasks each holds"
      usage(
        "Options:",
        "  --all   Include archived (inactive) lists"
      )
      param :all, type: "boolean", desc: "Include archived (inactive) lists"

      def call
        scope = options.flag?("all") ? TaskList.all : TaskList.active
        lists = scope.ordered.left_joins(:tasks)
          .select("task_lists.*, COUNT(CASE WHEN tasks.active THEN 1 END) AS active_task_count")
          .group("task_lists.id")

        {
          count: lists.length,
          lists: lists.map { |list| list_json(list) }
        }
      end

      private

      def list_json(list)
        {
          id: list.id,
          name: list.name,
          key: list.key,
          active: list.active,
          active_task_count: list.active_task_count.to_i,
          display_window: list.display_window? ? { start: list.display_start_time&.strftime("%H:%M"), end: list.display_end_time&.strftime("%H:%M") } : nil
        }
      end
    end
  end
end
