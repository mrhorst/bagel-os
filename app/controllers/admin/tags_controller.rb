module Admin
  # Admin-managed marketing tag vocabulary. The rule on each tag is what the
  # AI tagger shows Hermes when deciding which tags fit a photo.
  class TagsController < ApplicationController
    before_action :require_admin!
    before_action :set_tag, only: %i[edit update destroy]

    def index
      @tags = Tag.ordered
      @usage = Tagging.group(:tag_id).count
    end

    def new
      @tag = Tag.new(active: true, position: next_position)
    end

    def create
      @tag = Tag.new(tag_params)

      if @tag.save
        redirect_to admin_tags_path, notice: "Tag #{@tag.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @tag.update(tag_params)
        redirect_to admin_tags_path, notice: "Tag updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tag.destroy
      redirect_to admin_tags_path, notice: "Tag #{@tag.name} deleted."
    end

    private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def tag_params
      params.require(:tag).permit(:name, :slug, :instruction, :active, :position)
    end

    def next_position
      (Tag.maximum(:position) || 0) + 1
    end
  end
end
