module Agents
  module Commands
    # Create a task list. The list's key is derived from the name automatically
    # (TaskList#assign_key), so a name is all you need.
    class TasksCreateList < Command
      command "tasks:create-list"
      summary "Create a task list"
      mutates!
      usage(
        "Usage: bin/agent tasks:create-list --name \"Closing\"",
        "",
        "Options:",
        "  --name <text>     List name (required)",
        "  --position N      Display order (defaults to last)",
        "  --notes <text>    Optional notes",
        "  --display-start HH:MM / --display-end HH:MM  Only show the list during this window",
        "  --dry-run         Report what would be created without writing"
      )
      param :name, required: true, desc: "List name"
      param :position, type: "integer", desc: "Display order (defaults to last)"
      param :notes, desc: "Optional notes"
      param :"display-start", desc: "Only show the list from this time (HH:MM)"
      param :"display-end", desc: "Only show the list until this time (HH:MM)"
      param :"dry-run", type: "boolean", desc: "Report what would be created without writing"

      def call
        name = options.value("name")
        raise UsageError, "Provide --name" if name.blank?

        list = TaskList.new(
          name: name,
          notes: options.value("notes"),
          display_start_time: options.value("display-start"),
          display_end_time: options.value("display-end")
        )
        list.position = options.integer("position", 0)
        list.position = TaskList.maximum(:position).to_i + 1 if list.position.zero?

        if options.flag?("dry-run")
          return { dry_run: true, would: "create_task_list", name: name, position: list.position }
        end

        list.save!
        { created: true, task_list: { id: list.id, name: list.name, key: list.key, position: list.position } }
      rescue ActiveRecord::RecordInvalid => e
        raise UsageError, e.message
      end
    end
  end
end
