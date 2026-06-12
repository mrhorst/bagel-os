module AgentCli
  # JSON shapes for CLI output. Kept in one place so every action that
  # returns a task / follow-up / log book record looks the same to an agent.
  module Serializers
    module_function

    def task(task)
      {
        id: task.id,
        title: task.title,
        instructions: task.instructions,
        task_list: task_list_ref(task.task_list),
        recurrence_type: task.recurrence_type,
        active: task.active?,
        requires_photo_evidence: task.requires_photo_evidence?,
        position: task.position,
        starts_on: task.starts_on&.iso8601,
        ends_on: task.ends_on&.iso8601,
        one_time_on: task.one_time_on&.iso8601,
        due_time: task.due_time&.strftime("%H:%M"),
        weekdays: task.weekday_values,
        created_at: task.created_at&.iso8601,
        updated_at: task.updated_at&.iso8601
      }
    end

    def task_list(list, task_count: nil)
      {
        id: list.id,
        key: list.key,
        name: list.name,
        active: list.active?,
        position: list.position,
        notes: list.notes,
        display_start_time: list.display_start_time&.strftime("%H:%M"),
        display_end_time: list.display_end_time&.strftime("%H:%M"),
        active_task_count: task_count
      }.compact
    end

    def task_list_ref(list)
      { id: list.id, key: list.key, name: list.name }
    end

    def follow_up(follow_up, include_details: false)
      base = {
        id: follow_up.id,
        title: follow_up.title,
        description: follow_up.description,
        urgency: follow_up.urgency,
        status: follow_up.status,
        opened_at: follow_up.opened_at&.iso8601,
        opened_by: user_ref(follow_up.opened_by),
        assigned_to: user_ref(follow_up.assigned_to),
        resolved_at: follow_up.resolved_at&.iso8601,
        resolved_by: user_ref(follow_up.resolved_by),
        resolved_via: follow_up.resolved_via,
        resolution_note: follow_up.resolution_note,
        origin: follow_up.origin_type && { type: follow_up.origin_type, id: follow_up.origin_id }
      }
      return base unless include_details

      base.merge(
        notes: follow_up.notes.map { |note| follow_up_note(note) },
        spawned_tasks: follow_up.task_links.includes(:task).map do |link|
          { task_id: link.task_id, title: link.task.title, link_kind: link.link_kind }
        end
      )
    end

    def follow_up_note(note)
      {
        id: note.id,
        body: note.body,
        author: user_ref(note.author),
        created_at: note.created_at&.iso8601
      }
    end

    def log_book_section(section)
      {
        id: section.id,
        title: section.title,
        description: section.description,
        section_type: section.section_type,
        required: section.required?,
        allow_no_note: section.allow_no_note?,
        allow_follow_up: section.allow_follow_up?,
        unit_label: section.unit_label,
        value_decimals: section.value_decimals,
        fields: section.fields,
        position: section.position,
        active: section.active?
      }
    end

    def log_book_entry(entry, operating_day: Tasks::OperatingDay.new)
      {
        id: entry.id,
        operating_date: entry.operating_date&.iso8601,
        editable: entry.editable?(operating_day: operating_day),
        submitted_at: entry.submitted_at&.iso8601,
        submitted_by: user_ref(entry.submitted_by)
      }
    end

    def log_book_response(response)
      {
        id: response.id,
        section_id: response.log_book_section_id,
        section_title: response.section_title_snapshot,
        section_type: response.section_type_snapshot,
        value_text: response.value_text,
        value_number: response.value_number&.to_s("F"),
        value_grid: response.value_grid,
        no_note: response.no_note?,
        flagged_for_follow_up: response.flagged_for_follow_up?,
        urgency: response.urgency,
        display_value: response.display_value,
        last_submitted_at: response.last_submitted_at&.iso8601,
        last_submitted_by: user_ref(response.last_submitted_by)
      }
    end

    def user_ref(user)
      return nil if user.nil?
      { id: user.id, email: user.email_address, name: user.name }
    end
  end
end
