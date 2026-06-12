module AgentCli
  # bin/bagel tasks <action> — CRUD for task definitions. Mirrors
  # Tasks::ManageController: schedule validation lives on the Task model,
  # and every successful write refreshes open occurrences and broadcasts.
  class TasksCommand < BaseCommand
    WEEKDAY_NAMES = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

    def self.actions
      {
        "list" => :list,
        "show" => :show,
        "create" => :create,
        "update" => :update,
        "archive" => :archive,
        "reactivate" => :reactivate
      }
    end

    def usage
      <<~USAGE
        Usage: bin/bagel tasks <action> [options]

        Actions:
          list        [--all | --archived] [--list LIST]
          show        ID
          create      --title TITLE --list LIST [schedule options]
          update      ID [options to change]
          archive     ID
          reactivate  ID

        Schedule options (create/update):
          --recurrence TYPE     one_time | daily | weekly | monthly (default: daily)
          --due-time HH:MM      required for one_time/daily/weekly
          --starts-on DATE      required for daily/weekly/monthly (default: today on create)
          --ends-on DATE        optional end of the recurrence
          --one-time-on DATE    required for one_time
          --weekdays LIST       weekly only; comma-separated 0-6 or day names (e.g. mon,thu)

        Other options:
          --instructions TEXT, --position N, --[no-]photo-evidence

        LIST is a task list ID or key (see bin/bagel task-lists list).
      USAGE
    end

    def list(argv)
      options = {}
      parse_options(argv, "Usage: bin/bagel tasks list [options]") do |opts|
        opts.on("--all", "Include archived tasks") { options[:all] = true }
        opts.on("--archived", "Only archived tasks") { options[:archived] = true }
        opts.on("--list LIST", "Filter by task list (ID or key)") { |value| options[:list] = value }
      end

      tasks = Task.includes(:task_list).joins(:task_list)
        .order("task_lists.position ASC", "tasks.position ASC", "tasks.title ASC")
      tasks = tasks.where(active: true) unless options[:all] || options[:archived]
      tasks = tasks.where(active: false) if options[:archived]
      tasks = tasks.where(task_list: find_task_list!(options[:list])) if options[:list]

      { count: tasks.size, tasks: tasks.map { |task| Serializers.task(task) } }
    end

    def show(argv)
      parse_options(argv, "Usage: bin/bagel tasks show ID")
      task = Task.find(require_id!(argv, "bin/bagel tasks show ID"))
      { task: Serializers.task(task) }
    end

    def create(argv)
      attrs = parse_task_options(argv, "Usage: bin/bagel tasks create --title TITLE --list LIST [options]")

      raise Error, "--title is required." if attrs[:title].blank?
      raise Error, "--list is required (task list ID or key)." if attrs[:task_list].blank?

      attrs[:recurrence_type] ||= "daily"
      # Match the web form's default: recurring tasks start today unless told
      # otherwise.
      attrs[:starts_on] ||= Time.zone.today unless attrs[:recurrence_type] == "one_time"

      task = Task.new(attrs)
      task.save!
      after_write(task)
      { task: Serializers.task(task) }
    end

    def update(argv)
      attrs = parse_task_options(argv, "Usage: bin/bagel tasks update ID [options]")
      task = Task.find(require_id!(argv, "bin/bagel tasks update ID [options]"))
      raise Error, "Nothing to update — pass at least one option." if attrs.empty?

      task.update!(attrs)
      after_write(task)
      { task: Serializers.task(task) }
    end

    def archive(argv)
      parse_options(argv, "Usage: bin/bagel tasks archive ID")
      task = Task.find(require_id!(argv, "bin/bagel tasks archive ID"))
      task.archive!
      Tasks::LiveUpdates.task_state_changed!
      { task: Serializers.task(task) }
    end

    def reactivate(argv)
      parse_options(argv, "Usage: bin/bagel tasks reactivate ID")
      task = Task.find(require_id!(argv, "bin/bagel tasks reactivate ID"))
      task.reactivate!
      refresh_open_occurrences(task)
      Tasks::LiveUpdates.task_state_changed!
      { task: Serializers.task(task) }
    end

    private

    # Parses the shared create/update option set into model attributes.
    # Options are consumed from argv in place; positional args (like an ID)
    # are left behind for the caller.
    def parse_task_options(argv, banner)
      attrs = {}
      parse_options(argv, banner) do |opts|
        opts.on("--title TITLE", "Task title") { |value| attrs[:title] = value }
        opts.on("--list LIST", "Task list ID or key") { |value| attrs[:task_list] = find_task_list!(value) }
        opts.on("--instructions TEXT", "Free-text instructions") { |value| attrs[:instructions] = value }
        opts.on("--position N", Integer, "Sort position within the list") { |value| attrs[:position] = value }
        opts.on("--recurrence TYPE", "one_time | daily | weekly | monthly") do |value|
          attrs[:recurrence_type] = require_inclusion!(value, Task::RECURRENCE_TYPES, "--recurrence")
        end
        opts.on("--starts-on DATE", "First day of the schedule (YYYY-MM-DD)") do |value|
          attrs[:starts_on] = parse_date!(value, "--starts-on")
        end
        opts.on("--ends-on DATE", "Last day of the schedule (YYYY-MM-DD)") do |value|
          attrs[:ends_on] = parse_date!(value, "--ends-on")
        end
        opts.on("--one-time-on DATE", "Date of a one-time task (YYYY-MM-DD)") do |value|
          attrs[:one_time_on] = parse_date!(value, "--one-time-on")
        end
        opts.on("--due-time HH:MM", "Time of day the task is due") do |value|
          attrs[:due_time] = parse_time_of_day!(value, "--due-time")
        end
        opts.on("--weekdays LIST", "Comma-separated weekdays (0-6 or names)") do |value|
          attrs[:weekdays] = parse_weekdays!(value)
        end
        opts.on("--[no-]photo-evidence", "Require photo evidence on completion") do |value|
          attrs[:requires_photo_evidence] = value
        end
      end

      attrs
    end

    def parse_weekdays!(value)
      value.to_s.split(",").map do |token|
        token = token.strip.downcase
        next token.to_i if token.match?(/\A\d+\z/)

        index = WEEKDAY_NAMES.index { |name| name.start_with?(token) && token.length >= 3 }
        raise Error, "Unknown weekday #{token.inspect}. Use 0-6 or names like mon, tuesday." if index.nil?
        index
      end
    end

    def find_task_list!(value)
      list = if value.to_s.match?(/\A\d+\z/)
        TaskList.find_by(id: value)
      else
        TaskList.find_by(key: value)
      end
      raise Error, "No task list with ID or key #{value.inspect}. See bin/bagel task-lists list." if list.nil?
      list
    end

    # Same refresh the web controller performs after saving a task, so the
    # dashboard reflects the change immediately.
    def after_write(task)
      refresh_open_occurrences(task)
      Tasks::LiveUpdates.task_state_changed!
    end

    def refresh_open_occurrences(task)
      Tasks::OccurrenceBuilder.new.build!(
        from: Time.zone.today,
        to: [ Time.zone.today.end_of_month, task.ends_on ].compact.min
      )
    end
  end
end
