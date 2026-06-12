module AgentCli
  # bin/bagel log-book <action> — the daily log book. Reads any date;
  # writes only today's entry (same rule as the web UI: past entries are
  # read-only). Writes go through LogBook::SyncResponses so snapshots and
  # follow-up syncing behave exactly like a web save.
  class LogBookCommand < BaseCommand
    def self.actions
      {
        "sections" => :sections,
        "show" => :show,
        "set" => :set
      }
    end

    def usage
      <<~USAGE
        Usage: bin/bagel log-book <action> [options]

        Actions:
          sections   List the active log book sections (their IDs, types, fields)
          show       [--date YYYY-MM-DD]   Read an entry (default: today)
          set        --section SECTION [value options]   Write to TODAY's entry

        Value options for set (pick the one matching the section type):
          --text TEXT           long_text / short_text sections
          --number N            number sections
          --answer yes|no       yes_no sections
          --grid KEY=VALUE      multi sections; repeat for several fields,
                                use KEY= (empty) to clear a field
          --no-note             record "no note today" instead of a value

        Follow-up options for set:
          --flag                flag the section for follow-up
          --unflag              clear the flag (resolves the open follow-up)
          --urgency LEVEL       normal | important | urgent

        Other:
          --user EMAIL          attribute the write to a user

        set only changes what you pass; existing values, flags, and urgency
        on the section's response are preserved. Past entries are read-only.
      USAGE
    end

    def sections(argv)
      parse_options(argv, "Usage: bin/bagel log-book sections")
      sections = LogBookSection.active.ordered
      { count: sections.size, sections: sections.map { |s| Serializers.log_book_section(s) } }
    end

    def show(argv)
      options = {}
      parse_options(argv, "Usage: bin/bagel log-book show [--date YYYY-MM-DD]") do |opts|
        opts.on("--date DATE", "Entry date (default: today)") { |value| options[:date] = parse_date!(value, "--date") }
      end

      operating_day = Tasks::OperatingDay.new
      date = options[:date] || operating_day.today
      entry = LogBookEntry.find_by(operating_date: date)

      if entry.nil?
        return { date: date.iso8601, exists: false, responses: [] }
      end

      {
        date: date.iso8601,
        exists: true,
        entry: Serializers.log_book_entry(entry, operating_day: operating_day),
        responses: entry.log_book_responses
          .includes(:log_book_section, :last_submitted_by)
          .sort_by { |r| [ r.log_book_section&.position || 0, r.id ] }
          .map { |r| Serializers.log_book_response(r) }
      }
    end

    def set(argv)
      options = { grid: {} }
      parse_options(argv, "Usage: bin/bagel log-book set --section SECTION [options]") do |opts|
        opts.on("--section SECTION", "Section ID or exact title") { |value| options[:section] = value }
        opts.on("--text TEXT", "Value for long_text/short_text sections") { |value| options[:text] = value }
        opts.on("--number N", "Value for number sections") { |value| options[:number] = value }
        opts.on("--answer ANSWER", "yes | no, for yes_no sections") do |value|
          options[:answer] = require_inclusion!(value.downcase, %w[yes no], "--answer")
        end
        opts.on("--grid KEY=VALUE", "Field value for multi sections (repeatable)") do |value|
          key, field_value = value.split("=", 2)
          raise Error, "--grid expects KEY=VALUE, got #{value.inspect}." if key.blank? || field_value.nil?
          options[:grid][key] = field_value
        end
        opts.on("--no-note", "Record 'no note today'") { options[:no_note] = true }
        opts.on("--flag", "Flag the section for follow-up") { options[:flagged] = true }
        opts.on("--unflag", "Clear the follow-up flag") { options[:flagged] = false }
        opts.on("--urgency LEVEL", "normal | important | urgent") do |value|
          options[:urgency] = require_inclusion!(value, LogBookResponse::URGENCIES, "--urgency")
        end
        opts.on("--user EMAIL", "Attribute the write to a user") { |value| options[:user] = find_user!(value) }
      end
      raise Error, "--section is required (ID or exact title). See bin/bagel log-book sections." if options[:section].blank?

      section = find_section!(options[:section])
      check_value_options!(section, options)

      operating_day = Tasks::OperatingDay.new
      entry = LogBookEntry.find_or_create_by!(operating_date: operating_day.today)
      attrs = response_attrs(entry, section, options)

      ActiveRecord::Base.transaction do
        entry_attrs = { submitted_at: Time.current }
        entry_attrs[:submitted_by] = options[:user] if options[:user]
        entry.update!(entry_attrs)
        LogBook::SyncResponses.new(entry, user: options[:user]).call({ section.id => attrs })
      end

      response = entry.log_book_responses.find_by!(log_book_section: section)
      follow_up = FollowUp.where(origin: response).order(opened_at: :desc).first

      {
        entry: Serializers.log_book_entry(entry.reload, operating_day: operating_day),
        response: Serializers.log_book_response(response),
        follow_up: follow_up && Serializers.follow_up(follow_up)
      }
    end

    private

    def find_section!(value)
      section = if value.to_s.match?(/\A\d+\z/)
        LogBookSection.active.find_by(id: value)
      else
        LogBookSection.active.where("LOWER(title) = ?", value.to_s.downcase.strip).first
      end
      raise Error, "No active log book section with ID or title #{value.inspect}. See bin/bagel log-book sections." if section.nil?
      section
    end

    # Reject value flags that don't match the section type so an agent gets a
    # clear message instead of a silently dropped value.
    def check_value_options!(section, options)
      mismatches = {
        "--text" => options[:text] && !section.section_type.in?(%w[long_text short_text]),
        "--number" => options[:number] && section.section_type != "number",
        "--answer" => options[:answer] && section.section_type != "yes_no",
        "--grid" => options[:grid].any? && !section.multi?
      }.select { |_flag, wrong| wrong }.keys

      return if mismatches.empty?
      raise Error, "#{mismatches.join(', ')} cannot be used on a #{section.section_type} section (#{section.title.inspect})."
    end

    # Partial-update semantics: start from the persisted response (if any)
    # and overlay only what the caller passed. Passing any value clears
    # no_note unless --no-note was given explicitly.
    def response_attrs(entry, section, options)
      existing = entry.log_book_responses.find_by(log_book_section: section)
      value_given = options[:text] || options[:number] || options[:answer] || options[:grid].any?

      {
        value_text: options[:text] || options[:answer] || existing&.value_text,
        value_number: options[:number] || existing&.value_number,
        value_grid: (existing&.value_grid || {}).merge(options[:grid]),
        no_note: options.fetch(:no_note, value_given ? false : existing&.no_note? || false),
        flagged_for_follow_up: options.fetch(:flagged, existing&.flagged_for_follow_up? || false),
        urgency: options[:urgency] || existing&.urgency || "normal"
      }
    end
  end
end
