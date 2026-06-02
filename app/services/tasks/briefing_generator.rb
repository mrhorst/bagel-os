module Tasks
  class BriefingGenerator
    SCOPE_TYPE = "tasks_dashboard".freeze
    SCOPE_KEY = "today".freeze
    MAX_PRIORITY_ITEMS = 3

    def initialize(operating_day: OperatingDay.new, daily: nil, monthly: nil, gateway_client: BriefingGatewayClient.new)
      @operating_day = operating_day
      @daily = daily
      @monthly = monthly
      @gateway_client = gateway_client
    end

    def find_or_generate!
      snapshot = build_snapshot
      digest = digest_for(snapshot)
      briefing = TaskBriefing.find_or_initialize_by(scope_type: SCOPE_TYPE, scope_key: SCOPE_KEY)

      return briefing if briefing.persisted? && briefing.input_digest == digest && !briefing_stale?(briefing)

      attrs = briefing_attributes(snapshot, digest)
      briefing.update!(attrs)
      briefing
    end

    private

    attr_reader :operating_day, :gateway_client

    def build_snapshot
      daily_items = actionable_daily_occurrences.map { |occurrence| occurrence_snapshot(occurrence) }
      monthly_items = actionable_monthly_occurrences.map { |occurrence| occurrence_snapshot(occurrence, monthly: true) }

      (daily_items + monthly_items).sort_by do |item|
        [
          priority_bucket(item),
          item[:due_at].presence || Time.zone.local(operating_day.today.year, operating_day.today.month, operating_day.today.day, 23, 59),
          item[:list_position],
          item[:position],
          item[:title]
        ]
      end
    end

    def actionable_daily_occurrences
      Array(@daily || operating_day.actionable_daily_scope.includes(:task_list, :active_completion))
        .reject { |occurrence| occurrence.completed? || occurrence.missed?(operating_day: operating_day) }
        .reject { |occurrence| occurrence.stale_completed_carryover?(operating_day: operating_day) }
    end

    def actionable_monthly_occurrences
      Array(@monthly || operating_day.actionable_monthly_scope.includes(:task_list, :active_completion))
        .reject { |occurrence| occurrence.completed? || occurrence.missed?(operating_day: operating_day) }
    end

    def occurrence_snapshot(occurrence, monthly: false)
      status = monthly ? "monthly" : occurrence.status(operating_day: operating_day)

      {
        id: occurrence.id,
        title: occurrence.snapshot_title,
        instructions: occurrence.snapshot_instructions.to_s,
        list_name: occurrence.snapshot_list_name,
        list_position: occurrence.task_list.position,
        position: occurrence.position,
        due_at: occurrence.due_at,
        status: status,
        requires_photo_evidence: occurrence.requires_photo_evidence?
      }
    end

    def priority_bucket(item)
      return 0 if item[:status] == "late"
      return 1 if item[:due_at].present? && item[:due_at] <= operating_day.now + 90.minutes
      return 2 if item[:requires_photo_evidence]
      return 4 if item[:status] == "monthly"

      3
    end

    def digest_for(snapshot)
      normalized = snapshot.map do |item|
        item.merge(due_at: item[:due_at]&.iso8601, priority_bucket: priority_bucket(item))
      end
      Digest::SHA256.hexdigest(JSON.generate(snapshot: normalized, gateway: gateway_digest))
    end

    def briefing_attributes(snapshot, digest)
      gateway_attrs = gateway_briefing_attributes(snapshot)
      priority_items = gateway_attrs&.fetch(:priority_items) || snapshot.take(MAX_PRIORITY_ITEMS).map { |item| priority_item_for(item) }

      {
        generated_at: operating_day.now,
        stale_after: operating_day.now + 1.hour,
        input_digest: digest,
        headline: gateway_attrs&.fetch(:headline) || headline_for(snapshot),
        next_action: gateway_attrs&.fetch(:next_action) || next_action_for(priority_items),
        priority_items: priority_items,
        source_task_occurrence_ids: snapshot.map { |item| item[:id] }
      }
    end

    def briefing_stale?(briefing)
      briefing.stale_after.present? && briefing.stale_after <= operating_day.now
    end

    def gateway_digest
      return "disabled" unless gateway_client.configured?

      gateway_client.config_digest
    end

    def gateway_briefing_attributes(snapshot)
      return nil unless gateway_client.configured?

      response = gateway_client.call(gateway_payload(snapshot))
      normalize_gateway_response(response, snapshot)
    end

    def gateway_payload(snapshot)
      {
        "gateway" => "task_briefing",
        "version" => 1,
        "generated_at" => operating_day.now.iso8601,
        "scope" => {
          "type" => SCOPE_TYPE,
          "key" => SCOPE_KEY,
          "operating_date" => operating_day.today.iso8601
        },
        "instructions" => [
          "Prioritize late work, due-soon work, food-safety-sensitive work, photo-evidence work, then monthly work.",
          "Do not invent tasks, legal requirements, completion claims, or compliance claims.",
          "Return JSON with headline, next_action, and up to three priority_items."
        ],
        "tasks" => snapshot.map { |item| gateway_task_payload(item) }
      }
    end

    def gateway_task_payload(item)
      {
        "task_occurrence_id" => item[:id],
        "title" => item[:title],
        "instructions" => item[:instructions],
        "list_name" => item[:list_name],
        "status" => item[:status],
        "due_at" => item[:due_at]&.iso8601,
        "due_label" => due_label_for(item),
        "requires_photo_evidence" => item[:requires_photo_evidence],
        "priority_bucket" => priority_bucket(item)
      }
    end

    def normalize_gateway_response(response, snapshot)
      return nil unless response.is_a?(Hash)

      headline = response["headline"].to_s.squish.presence || response["summary"].to_s.squish
      priority_items = normalize_gateway_priority_items(response["priority_items"].presence || response["items"], snapshot)
      next_action = response["next_action"].to_s.squish.presence || next_action_for(priority_items)
      return nil if headline.blank? || next_action.blank?

      {
        headline: headline,
        next_action: next_action,
        priority_items: priority_items.presence || snapshot.take(MAX_PRIORITY_ITEMS).map { |item| priority_item_for(item) }
      }
    end

    def normalize_gateway_priority_items(items, snapshot)
      allowed = snapshot.index_by { |item| item[:id].to_i }

      Array(items).filter_map do |item|
        task = gateway_priority_task(item, snapshot, allowed)
        next if task.blank?

        {
          "task_occurrence_id" => task[:id],
          "title" => item["title"].to_s.presence || task[:title],
          "list_name" => item["list_name"].to_s.presence || task[:list_name],
          "status" => item["status"].to_s.presence || task[:status],
          "due_label" => gateway_due_label(item).presence || due_label_for(task),
          "reason" => gateway_reason(item).presence || reason_for(task)
        }
      end.first(MAX_PRIORITY_ITEMS)
    end

    def gateway_priority_task(item, snapshot, allowed)
      task_occurrence_id = item["task_occurrence_id"].presence
      return allowed[task_occurrence_id.to_i] if task_occurrence_id.present?

      title = item["title"].to_s.squish
      return nil if title.blank?

      matches = snapshot.select { |task| task[:title] == title }
      list_name = item["list_name"].to_s.squish
      status = item["status"].to_s.squish
      due_label = gateway_due_label(item)

      matches = matches.select { |task| task[:list_name] == list_name } if list_name.present?
      matches = matches.select { |task| task[:status] == status } if status.present?
      matches = matches.select { |task| due_label_for(task) == due_label } if due_label.present?
      matches.one? ? matches.first : nil
    end

    def gateway_due_label(item)
      item["due_label"].to_s.presence || item["due"].to_s.presence
    end

    def gateway_reason(item)
      item["reason"].to_s.squish.presence ||
        item["why_it_matters"].to_s.squish.presence ||
        item["note"].to_s.squish.presence
    end

    def headline_for(snapshot)
      return "No open task work needs attention right now." if snapshot.empty?

      late_count = snapshot.count { |item| item[:status] == "late" }
      due_soon_count = snapshot.count { |item| item[:status] != "late" && item[:due_at].present? && item[:due_at] <= operating_day.now + 90.minutes }
      monthly_count = snapshot.count { |item| item[:status] == "monthly" }

      if late_count.positive?
        "#{late_count} #{'task'.pluralize(late_count)} #{late_count == 1 ? 'is' : 'are'} late. Clear #{late_count == 1 ? 'it' : 'those'} first, then protect the next due times."
      elsif due_soon_count.positive?
        "#{due_soon_count} #{'task'.pluralize(due_soon_count)} #{due_soon_count == 1 ? 'is' : 'are'} coming up soon. Stay ahead of the rush by knocking #{due_soon_count == 1 ? 'it' : 'them'} out now."
      elsif monthly_count == snapshot.size
        "Today is clear. There #{monthly_count == 1 ? 'is' : 'are'} #{monthly_count} monthly task #{'item'.pluralize(monthly_count)} still open."
      else
        "#{snapshot.size} open task #{'item'.pluralize(snapshot.size)} #{snapshot.size == 1 ? 'is' : 'are'} ready for the shift."
      end
    end

    def next_action_for(priority_items)
      first = priority_items.first
      return "Use the quiet moment to review task lists, clean as you go, and keep the dashboard current." if first.blank?

      "Start with #{first['title']} in #{first['list_name']}. #{first['reason']}"
    end

    def priority_item_for(item)
      {
        "task_occurrence_id" => item[:id],
        "title" => item[:title],
        "list_name" => item[:list_name],
        "status" => item[:status],
        "due_label" => due_label_for(item),
        "reason" => reason_for(item)
      }
    end

    def due_label_for(item)
      return "This month" if item[:status] == "monthly"
      return "No due time" if item[:due_at].blank?

      item[:due_at].strftime("%-I:%M %p")
    end

    def reason_for(item)
      return "It is already late, so finishing it protects the rest of the shift." if item[:status] == "late"
      return "It is due soon and can affect service readiness." if item[:due_at].present? && item[:due_at] <= operating_day.now + 90.minutes
      return "It needs photo evidence, so it may take a little more attention." if item[:requires_photo_evidence]
      return "It is monthly work, so use slower moments instead of letting it pile up." if item[:status] == "monthly"

      "It is the next open item in the current task order."
    end
  end
end
