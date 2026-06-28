module Agents
  # Resolves the fuzzy references a voice agent produces ("the cream cheese
  # task", "complete as Maria") into the exact records the write services need.
  # Refuses to guess when a reference is ambiguous — it hands back the
  # candidates so the agent can ask the user instead.
  module TaskTargeting
    module_function

    # Resolve one TaskOccurrence from an explicit id or a fuzzy title match
    # against the day's actionable occurrences (the same set staff see).
    def resolve_occurrence(options, operating_day)
      if (id = options.value("occurrence")).present?
        return TaskOccurrence.find_by(id: id) ||
          (raise Command::NotFoundError, "No task occurrence with id #{id}")
      end

      query = options.value("task")
      raise Command::UsageError, "Provide --occurrence <id> or --task <name>" if query.blank?

      candidates = actionable_occurrences(operating_day)
      matches = candidates.select { |o| o.snapshot_title.to_s.downcase.include?(query.downcase) }

      case matches.size
      when 0
        raise Command::NotFoundError, "No actionable task matching #{query.inspect} for #{operating_day.today.iso8601}"
      when 1
        matches.first
      else
        raise Command::AmbiguousError.new(
          "#{matches.size} tasks match #{query.inspect}; specify --occurrence <id>",
          candidates: matches.map { |o| { id: o.id, title: o.snapshot_title, list: o.snapshot_list_name } }
        )
      end
    end

    # Resolve a TaskList from --list, accepting an id or a name (exact match
    # first, then a unique case-insensitive substring). Used when filing a new
    # task into an existing list.
    def resolve_task_list(options, key: "list")
      raw = options.value(key)
      raise Command::UsageError, "Provide --#{key} <name|id>" if raw.blank?

      if raw.match?(/\A\d+\z/)
        return TaskList.find_by(id: raw) || (raise Command::NotFoundError, "No task list with id #{raw}")
      end

      exact = TaskList.where("LOWER(name) = ?", raw.strip.downcase).to_a
      candidates = exact.presence || TaskList.where("LOWER(name) LIKE ?", "%#{raw.strip.downcase}%").to_a

      case candidates.size
      when 0
        raise Command::NotFoundError, "No task list matching #{raw.inspect}"
      when 1
        candidates.first
      else
        raise Command::AmbiguousError.new(
          "#{candidates.size} task lists match #{raw.inspect}; use the exact name or --#{key} <id>",
          candidates: candidates.map { |l| { id: l.id, name: l.name } }
        )
      end
    end

    # Resolve the attributed user from --user, accepting an id, exact email, or
    # case-insensitive name.
    def resolve_user(options)
      raw = options.value("user")
      raise Command::UsageError, "Provide --user <email|name|id> for attribution" if raw.blank?

      if raw.match?(/\A\d+\z/)
        return User.find_by(id: raw) || (raise Command::NotFoundError, "No user with id #{raw}")
      end

      by_email = User.find_by(email_address: raw.strip.downcase)
      return by_email if by_email

      by_name = User.where("LOWER(name) = ?", raw.strip.downcase).to_a
      case by_name.size
      when 0
        raise Command::NotFoundError, "No user matching #{raw.inspect}"
      when 1
        by_name.first
      else
        raise Command::AmbiguousError.new(
          "#{by_name.size} users named #{raw.inspect}; use their email or --user <id>",
          candidates: by_name.map { |u| { id: u.id, name: u.name, email: u.email_address } }
        )
      end
    end

    def actionable_occurrences(operating_day)
      Tasks::OccurrenceBuilder.new(operating_day: operating_day).build!(from: operating_day.today, to: operating_day.today)
      Tasks::OccurrenceBuilder.new(operating_day: operating_day)
        .build!(from: operating_day.today.beginning_of_month, to: operating_day.today.end_of_month)

      daily = operating_day.actionable_daily_scope.includes(:task_list, :active_completion).to_a
      monthly = operating_day.actionable_monthly_scope.includes(:task_list, :active_completion).to_a
      daily + monthly
    end

    def occurrence_summary(occurrence, operating_day)
      {
        id: occurrence.id,
        title: occurrence.snapshot_title,
        list: occurrence.snapshot_list_name,
        status: occurrence.status(operating_day: operating_day),
        requires_photo_evidence: occurrence.requires_photo_evidence
      }
    end
  end
end
