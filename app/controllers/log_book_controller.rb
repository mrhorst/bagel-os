class LogBookController < ApplicationController
  require_module_access :log_book

  def index
    @today = Time.zone.today
    @operating_date = parse_date(params[:date], default: @today)
    @entry = entry_for(@operating_date, create: @operating_date == @today)
    @sections = sections_for(@entry, editable: @entry.editable?(today: @today))
    @responses_by_section_id = @entry.log_book_responses.index_by(&:log_book_section_id)
    @editable = @entry.editable?(today: @today)
    @recent_entries = LogBookEntry.recent_first.limit(7)
    @unresolved_follow_ups = LogBookResponse.unresolved
      .includes(:log_book_section, :log_book_entry)
      .recent_first
      .limit(10)
  end

  def update
    @today = Time.zone.today
    operating_date = parse_date(params[:operating_date], default: @today)

    unless operating_date == @today
      redirect_to log_book_path(date: operating_date), alert: "Past log book entries are read-only."
      return
    end

    entry = entry_for(operating_date, create: true)

    ActiveRecord::Base.transaction do
      entry.update!(submitted_by: Current.user, submitted_at: Time.current)
      sync_responses!(entry)
    end

    redirect_to log_book_path(date: operating_date), notice: "Log Book saved."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to log_book_path(date: operating_date), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def entry_for(operating_date, create:)
    if create
      LogBookEntry.find_or_create_by!(operating_date: operating_date)
    else
      LogBookEntry.find_or_initialize_by(operating_date: operating_date)
    end
  end

  def sections_for(entry, editable:)
    return LogBookSection.active.ordered if editable

    section_ids = entry.log_book_responses.select(:log_book_section_id)
    LogBookSection.where(id: section_ids).ordered
  end

  def sync_responses!(entry)
    response_params.each do |section_id, attrs|
      section = LogBookSection.active.find(section_id)
      response = entry.log_book_responses.find_or_initialize_by(log_book_section: section)
      no_note = ActiveModel::Type::Boolean.new.cast(attrs[:no_note])

      response.assign_attributes(
        section_title_snapshot: section.title,
        section_type_snapshot: section.section_type,
        no_note: no_note,
        flagged_for_follow_up: ActiveModel::Type::Boolean.new.cast(attrs[:flagged_for_follow_up]),
        urgency: attrs[:urgency].presence || "normal",
        value_text: value_text_for(section, attrs, no_note),
        value_number: no_note ? nil : attrs[:value_number].presence
      )
      response.save!
    end
  end

  def value_text_for(section, attrs, no_note)
    return nil if no_note || section.section_type == "number"

    attrs[:value_text].presence
  end

  def response_params
    return {} unless params[:responses].respond_to?(:to_unsafe_h)

    params[:responses].to_unsafe_h.transform_values do |attrs|
      attrs.slice(
        "value_text",
        "value_number",
        "no_note",
        "flagged_for_follow_up",
        "urgency"
      ).symbolize_keys
    end
  end

  def parse_date(value, default:)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    default
  end
end
