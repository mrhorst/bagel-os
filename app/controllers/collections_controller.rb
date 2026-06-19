class CollectionsController < ApplicationController
  require_module_access :marketing

  before_action :set_collection, only: %i[show edit update destroy]

  def index
    @collections = Collection.ordered
    @counts = CollectionMembership.group(:collection_id).count
  end

  def show
    @assets = @collection.photo_assets
      .with_attached_photo.includes(:confirmed_tags)
      .order("collection_memberships.position", "collection_memberships.id")
  end

  def new
    @collection = Collection.new(position: next_position)
  end

  def create
    @collection = Collection.new(collection_params)
    @collection.created_by = Current.user

    if @collection.save
      redirect_to @collection, notice: "Collection #{@collection.name} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collection.update(collection_params)
      redirect_to @collection, notice: "Collection updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to collections_path, notice: "Collection #{@collection.name} deleted."
  end

  private

  def set_collection
    @collection = Collection.find(params[:id])
  end

  def collection_params
    params.require(:collection).permit(:name, :slug, :description, :position)
  end

  def next_position
    (Collection.maximum(:position) || 0) + 1
  end
end
