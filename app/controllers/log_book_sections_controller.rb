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
    params.require(:log_book_section).permit(
      :title,
      :description,
      :section_type,
      :position,
      :required,
      :allow_no_note,
      :unit_label
    )
  end
end
