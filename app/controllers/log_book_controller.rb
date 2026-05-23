class LogBookController < ApplicationController
  RESPONSE_FIELDS = %i[value_text value_number no_note flagged_for_follow_up urgency].freeze

  require_module_access :log_book

  def index
    setup_view_state
  end

  def update
    operating_day = Tasks::OperatingDay.new
    today = operating_day.today
    operating_date = parse_date(params[:operating_date], today: today)

    if operating_date > today
      redirect_to log_book_path, alert: "You can't open a future log book."
      return
    elsif operating_date != today
      redirect_to log_book_path(date: operating_date), alert: "Past log book entries are read-only."
      return
    end

    entry = entry_for(operating_date, create: true)
    saved_at = Time.current

    ActiveRecord::Base.transaction do
      entry.update!(submitted_by: Current.user, submitted_at: saved_at)
      sync_responses!(entry, response_params)
    end

    setup_view_state
    respond_to do |format|
      format.turbo_stream { render turbo_stream: save_streams(saved_at: saved_at) }
      format.html         { redirect_to log_book_path(date: operating_date), notice: "Saved." }
    end
  rescue ActiveRecord::RecordInvalid => error
    setup_view_state(error_record: error.record, raw_params: response_params)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: save_streams(error: error.record), status: :unprocessable_entity
      end
      format.html do
        flash.now[:alert] = error.record.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end
  end

  private

  # Builds the @ivars index.html.erb needs. Reused on the happy path (GET),
  # on validation errors (re-render), and after a successful turbo_stream
  # save (so we can replace the per-section meta lines).
  def setup_view_state(error_record: nil, raw_params: {})
    operating_day = Tasks::OperatingDay.new
    @today = operating_day.today

    requested = parse_date(params[:date], today: @today)
    if requested > @today
      redirect_to log_book_path, alert: "You can't open a future log book."
      return
    end
    @operating_date = requested

    @entry = entry_for(@operating_date, create: @operating_date == @today)
    @editable = @entry.editable?(operating_day: operating_day)
    @sections = sections_for(@entry, editable: @editable)
    @responses_by_section_id = @entry.log_book_responses.index_by(&:log_book_section_id)

    @prev_date = @operating_date - 1
    @next_date = @operating_date < @today ? @operating_date + 1 : nil

    @recent_entries = LogBookEntry.recent_first.limit(7).includes(:log_book_responses)
    @unresolved_follow_ups = LogBookResponse.unresolved
      .includes(:log_book_section, :log_book_entry, :last_submitted_by)
      .recent_first
      .limit(10)

    @response_errors = build_response_errors(error_record)
    @form_overrides  = raw_params
  end

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

  def sync_responses!(entry, response_params)
    response_params.each do |section_id, attrs|
      section = LogBookSection.active.find(section_id)
      response = entry.log_book_responses.find_or_initialize_by(log_book_section: section)
      no_note = ActiveModel::Type::Boolean.new.cast(attrs[:no_note])

      response.assign_attributes(
        section_title_snapshot: section.title,
        section_type_snapshot: section.section_type,
        value_decimals_snapshot: section.value_decimals,
        no_note: no_note,
        flagged_for_follow_up: section.allow_follow_up? &&
          ActiveModel::Type::Boolean.new.cast(attrs[:flagged_for_follow_up]),
        urgency: section.allow_follow_up? ? (attrs[:urgency].presence || "normal") : "normal",
        value_text: value_text_for(section, attrs, no_note),
        value_number: no_note ? nil : attrs[:value_number].presence
      )

      # Only attribute a write to a user if the response actually changed.
      # Touching the form and resaving without edits shouldn't rewrite who
      # last filled out the section.
      if response.new_record? || response.changed?
        response.last_submitted_by = Current.user
        response.last_submitted_at = Time.current
      end

      response.save!
    end
  end

  def value_text_for(section, attrs, no_note)
    return nil if no_note || section.section_type == "number"

    attrs[:value_text].presence
  end

  # Whitelist responses with a proper StrongParameters pass instead of
  # to_unsafe_h. Renames or new fields won't accidentally leak through.
  def response_params
    return {} unless params[:responses].is_a?(ActionController::Parameters)

    permitted = params.require(:responses).permit(
      params[:responses].keys.index_with { RESPONSE_FIELDS.map(&:to_s) }
    )

    permitted.to_h.transform_values { |attrs| attrs.symbolize_keys }
  end

  def build_response_errors(error_record)
    return {} unless error_record.is_a?(LogBookResponse)

    { error_record.log_book_section_id => error_record.errors }
  end

  # Junk dates fall back to today. Future dates are returned as-is so the
  # caller (setup_view_state) can redirect with a helpful alert.
  def parse_date(value, today:)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    today
  end

  # Turbo Stream payload returned by save (both autosave and explicit click).
  # Refreshes the global "Saved at" indicator, every section's meta line, and
  # every section's per-card error region (clearing stale errors too).
  def save_streams(saved_at: nil, error: nil)
    streams = [
      turbo_stream.replace(
        "log_book_save_status",
        partial: "log_book/save_status",
        locals: { saved_at: saved_at, error: error }
      )
    ]
    @sections.each do |section|
      streams << turbo_stream.replace(
        "log_book_response_meta_#{section.id}",
        partial: "log_book/response_meta",
        locals: { section: section, response: @responses_by_section_id[section.id] }
      )
      streams << turbo_stream.replace(
        "log_book_section_error_#{section.id}",
        partial: "log_book/section_error",
        locals: { section: section, errors: @response_errors[section.id] }
      )
    end
    streams
  end
end
