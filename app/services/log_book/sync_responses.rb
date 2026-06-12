module LogBook
  # Writes a batch of log book responses onto an entry: snapshots the section
  # state at save time, normalizes values by section type, and keeps each
  # response's FollowUp in sync. Shared by the web save path
  # (LogBookController#update) and the agent CLI (bin/bagel log-book set).
  class SyncResponses
    def initialize(entry, user: nil)
      @entry = entry
      @user = user
    end

    # response_params is { section_id => attrs } where attrs may contain
    # :value_text, :value_number, :no_note, :flagged_for_follow_up,
    # :urgency and :value_grid.
    def call(response_params)
      response_params.each do |section_id, attrs|
        section = LogBookSection.active.find(section_id)
        response = @entry.log_book_responses.find_or_initialize_by(log_book_section: section)
        no_note = boolean(attrs.fetch(:no_note, false))

        response.assign_attributes(
          section_title_snapshot: section.title,
          section_type_snapshot: section.section_type,
          value_decimals_snapshot: section.value_decimals,
          no_note: no_note,
          flagged_for_follow_up: section.allow_follow_up? && boolean(attrs[:flagged_for_follow_up]),
          urgency: section.allow_follow_up? ? (attrs[:urgency].presence || "normal") : "normal",
          value_text: value_text_for(section, attrs, no_note),
          value_number: no_note ? nil : attrs[:value_number].presence,
          value_grid: value_grid_for(section, attrs, no_note),
          fields_snapshot: section.multi? ? section.fields : []
        )

        # Only attribute a write to a user if the response actually changed.
        # Touching the form and resaving without edits shouldn't rewrite who
        # last filled out the section.
        if response.new_record? || response.changed?
          response.last_submitted_by = @user
          response.last_submitted_at = Time.current
        end

        response.save!
        FollowUps::SyncFromLogBookResponse.new(response, user: @user).call
      end
    end

    private

    def value_text_for(section, attrs, no_note)
      return nil if no_note || section.section_type.in?(%w[number multi])

      attrs[:value_text].presence
    end

    # Strip blank entries so a multi-input section saved with empty fields
    # round-trips as an empty hash rather than a hash of blank strings.
    def value_grid_for(section, attrs, no_note)
      return {} unless section.multi?
      return {} if no_note

      raw = attrs[:value_grid]
      return {} unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

      raw.to_h.each_with_object({}) do |(key, value), acc|
        next if value.to_s.strip.empty?
        acc[key.to_s] = value.to_s.strip
      end
    end

    def boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
