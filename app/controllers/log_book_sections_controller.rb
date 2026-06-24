class LogBookSectionsController < ApplicationController
  before_action :require_admin!
  before_action :set_section, only: %i[edit update archive reactivate]

  def index
    @sections = LogBookSection.ordered
  end

  def new
    @section = LogBookSection.new(section_type: "long_text", allow_no_note: true)
  end

  def create
    @section = LogBookSection.new(section_params)
    @section.created_by = Current.user

    if @section.save
      redirect_to log_book_sections_path, notice: "Log section created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @section.update(section_params)
      redirect_to log_book_sections_path, notice: "Log section updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @section.archive!
    redirect_to log_book_sections_path, notice: "Log section archived."
  end

  def reactivate
    @section.update!(active: true)
    redirect_to log_book_sections_path, notice: "Log section reactivated."
  end

  private

  def set_section
    @section = LogBookSection.find(params[:id])
  end

  def section_params
    permitted = params.require(:log_book_section).permit(
      :title,
      :description,
      :section_type,
      :position,
      :allow_no_note,
      :allow_follow_up,
      :unit_label,
      :value_decimals,
      fields: %i[key label type unit_label value_decimals]
    )

    permitted[:fields] = normalize_fields(permitted[:fields]) if permitted[:fields].present?
    permitted
  end

  # Drop only the rows the user never touched — the seeded blank starter, or a
  # row added then cleared. A row carrying any real content (a label, a unit, a
  # non-default type) is kept even when its label is blank, so the model's
  # "row N needs a label" validation fires and the partially-filled row is
  # preserved on re-render. Stripping such rows here used to silently discard
  # them: a manager who filled an input's unit but forgot its label got a
  # "Log section created." toast and a section missing that input. Derive a
  # stable key from the label when one is missing (kept blank-label rows carry
  # no key — they can't save until the label is supplied anyway).
  def normalize_fields(raw_fields)
    used = []
    raw_fields.filter_map do |row|
      row = row.to_h.with_indifferent_access
      next if row_blank?(row)

      label = row["label"].to_s.strip
      key = row["key"].to_s.strip.presence
      key ||= slugify(label, used) if label.present?
      used << key if key.present?
      {
        "key"            => key.to_s,
        "label"          => label,
        "type"           => row["type"].presence || "number",
        "unit_label"     => row["unit_label"].to_s.strip,
        "value_decimals" => row["value_decimals"].to_i.clamp(0, 6)
      }
    end
  end

  # A row is discardable only when the user left it entirely untouched. Type
  # ("number") and decimals (0) default to non-blank on a fresh row, so they
  # can't signal intent — a label or a unit label is what marks a row as one
  # the user meant to keep.
  def row_blank?(row)
    row["label"].to_s.strip.blank? &&
      row["unit_label"].to_s.strip.blank? &&
      row["type"].to_s.strip.presence.in?([ nil, "number" ]) &&
      row["value_decimals"].to_i.zero?
  end

  def slugify(label, used)
    base = label.parameterize(separator: "_").presence || "field"
    candidate = base
    n = 1
    while used.include?(candidate)
      n += 1
      candidate = "#{base}_#{n}"
    end
    candidate
  end
end
