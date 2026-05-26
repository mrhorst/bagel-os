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

  # Drop blank rows (user added then deleted via Stimulus, or hit Save with
  # an empty row) and derive a stable key from the label when missing.
  def normalize_fields(raw_fields)
    used = []
    raw_fields.filter_map do |row|
      row = row.to_h.with_indifferent_access
      label = row["label"].to_s.strip
      next if label.blank?

      key = row["key"].to_s.strip.presence || slugify(label, used)
      used << key
      {
        "key"            => key,
        "label"          => label,
        "type"           => row["type"].presence || "number",
        "unit_label"     => row["unit_label"].to_s.strip,
        "value_decimals" => row["value_decimals"].to_i.clamp(0, 6)
      }
    end
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
