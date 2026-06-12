module AgentCli
  # bin/bagel task-lists <action> — the lists tasks live on. Create mirrors
  # Tasks::TaskListsController: the key is derived from the name and the
  # position is auto-assigned when not given.
  class TaskListsCommand < BaseCommand
    def self.actions
      {
        "list" => :list,
        "create" => :create
      }
    end

    def usage
      <<~USAGE
        Usage: bin/bagel task-lists <action> [options]

        Actions:
          list      [--all]
          create    --name NAME [--notes TEXT] [--position N]
      USAGE
    end

    def list(argv)
      options = {}
      parse_options(argv, "Usage: bin/bagel task-lists list [--all]") do |opts|
        opts.on("--all", "Include archived task lists") { options[:all] = true }
      end

      lists = TaskList.ordered
      lists = lists.active unless options[:all]
      task_counts = Task.active.group(:task_list_id).count

      {
        count: lists.size,
        task_lists: lists.map { |list| Serializers.task_list(list, task_count: task_counts.fetch(list.id, 0)) }
      }
    end

    def create(argv)
      attrs = {}
      parse_options(argv, "Usage: bin/bagel task-lists create --name NAME [options]") do |opts|
        opts.on("--name NAME", "Task list name") { |value| attrs[:name] = value }
        opts.on("--notes TEXT", "Free-text notes") { |value| attrs[:notes] = value }
        opts.on("--position N", Integer, "Sort position") { |value| attrs[:position] = value }
      end
      raise Error, "--name is required." if attrs[:name].blank?

      list = TaskList.new(attrs)
      list.position = TaskList.maximum(:position).to_i + 1 if list.position.to_i.zero?
      list.save!
      Tasks::LiveUpdates.task_state_changed!

      { task_list: Serializers.task_list(list, task_count: 0) }
    end
  end
end
