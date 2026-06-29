module Agents
  module Commands
    # Create a task inside an existing list. Mirrors the manage controller:
    # builds the Task, then materializes its open occurrences so it shows up on
    # the work surface right away.
    #
    # Schedule shape depends on --recurrence (the model enforces it):
    #   daily   : --due-time (--starts-on defaults to today)
    #   weekly  : --due-time + --weekdays (--starts-on defaults to today)
    #   monthly : (--starts-on defaults to today)
    #   one_time: --one-time-on + --due-time
    class TasksCreate < Command
      command "tasks:create"
      summary "Create a task in a list"
      mutates!
      usage(
        "Usage: bin/agent tasks:create --list \"Closing\" --title \"Lock the doors\" --due-time 22:00",
        "",
        "Options:",
        "  --list <name|id>   Target list (required)",
        "  --title <text>     Task title (required)",
        "  --recurrence <kind>  one_time | daily | weekly | monthly (default daily)",
        "  --due-time HH:MM   Time of day it's due (required except monthly)",
        "  --starts-on DATE   First active date (defaults to today)",
        "  --ends-on DATE     Last active date (optional)",
        "  --one-time-on DATE For --recurrence one_time",
        "  --weekdays 1,2,5   For --recurrence weekly (0=Sun..6=Sat)",
        "  --instructions <text>  Plain-text guidance",
        "  --requires-photo   Require photo evidence at completion",
        "  --dry-run          Report what would be created without writing"
      )
      param :list, required: true, desc: "Target list (name or id)"
      param :title, required: true, desc: "Task title"
      param :recurrence, desc: "one_time | daily | weekly | monthly (default daily)"
      param :"due-time", desc: "Time of day it's due (HH:MM)"
      param :"starts-on", type: "date", desc: "First active date (defaults to today)"
      param :"ends-on", type: "date", desc: "Last active date"
      param :"one-time-on", type: "date", desc: "Date for a one_time task"
      param :weekdays, desc: "Comma list of weekdays for weekly (0=Sun..6=Sat)"
      param :instructions, desc: "Plain-text guidance"
      param :"requires-photo", type: "boolean", desc: "Require photo evidence at completion"
      param :"dry-run", type: "boolean", desc: "Report what would be created without writing"

      def call
        list = TaskTargeting.resolve_task_list(options)
        title = options.value("title")
        raise UsageError, "Provide --title" if title.blank?

        recurrence = options.value("recurrence", "daily")
        unless Task::RECURRENCE_TYPES.include?(recurrence)
          raise UsageError, "--recurrence must be one of #{Task::RECURRENCE_TYPES.join(', ')}"
        end

        task = build_task(list, title, recurrence)

        if options.flag?("dry-run")
          task.validate
          raise UsageError, task.errors.full_messages.join("; ") if task.errors.any?

          return { dry_run: true, would: "create_task", title: title, list: list.name, recurrence: recurrence }
        end

        task.save!
        Tasks::OccurrenceBuilder.new.build!(
          from: Time.zone.today,
          to: [ Time.zone.today.end_of_month, task.ends_on ].compact.min
        )

        { created: true, task: task_json(task, list) }
      rescue ActiveRecord::RecordInvalid => e
        raise UsageError, e.message
      end

      private

      def build_task(list, title, recurrence)
        Task.new(
          task_list: list,
          title: title,
          recurrence_type: recurrence,
          instructions: options.value("instructions"),
          due_time: options.value("due-time"),
          starts_on: options.value("starts-on").presence || default_starts_on(recurrence),
          ends_on: options.value("ends-on"),
          one_time_on: options.value("one-time-on"),
          weekdays: parse_weekdays,
          requires_photo_evidence: options.flag?("requires-photo"),
          position: 0
        )
      end

      # one_time tasks anchor on --one-time-on, not starts_on; the rest default
      # their first active date to today so they begin producing work now.
      def default_starts_on(recurrence)
        recurrence == "one_time" ? nil : Time.zone.today
      end

      def parse_weekdays
        raw = options.value("weekdays")
        return [] if raw.blank?

        raw.split(",").map(&:strip).reject(&:blank?).map(&:to_i)
      end

      def task_json(task, list)
        {
          id: task.id,
          title: task.title,
          list: list.name,
          recurrence_type: task.recurrence_type,
          due_time: task.due_time&.strftime("%H:%M"),
          starts_on: task.starts_on&.iso8601,
          weekdays: task.weekday_values,
          requires_photo_evidence: task.requires_photo_evidence
        }
      end
    end
  end
end
