class OrderGuidesController < ApplicationController
  require_module_access :order_guides

  def index
    load_guides_index
    @new_order_guide = OrderGuide.new
  end

  def show
    @order_guide = OrderGuide
      .includes(:order_guide_sections, order_guide_memberships: [ :order_guide_section, { inventory_item: [ :inventory_section, :product, :preferred_supplier ] } ])
      .find(params[:id])
    @memberships = @order_guide.order_guide_memberships
      .active
      .joins(:inventory_item)
      .includes(:order_guide_section, inventory_item: [ :inventory_section, :product, :preferred_supplier ])
      .order(:position, "inventory_items.name")
    @sections = @order_guide.active_sections
    active_item_ids = @memberships.map(&:inventory_item_id)
    @available_inventory_items = InventoryItem.active
      .where.not(id: active_item_ids)
      .ordered
  end

  def create
    @new_order_guide = OrderGuide.new(order_guide_params)
    @new_order_guide.position = OrderGuide.maximum(:position).to_i + 1

    if @new_order_guide.save
      redirect_to order_guides_path, notice: "Order guide created."
    else
      # Re-render the index in place (instead of redirecting to a fresh form)
      # so a recoverable name problem — a duplicate or blank name — doesn't
      # discard the notes the manager typed. The create form repopulates from
      # @new_order_guide and surfaces the errors inline, matching the in-place
      # recovery the rest of the app already uses for failed creates (collections,
      # inventory counts) rather than a flash that drops the user's input.
      load_guides_index
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @order_guide = OrderGuide.find(params[:id])

    if @order_guide.update(order_guide_params)
      redirect_to order_guides_path, notice: "Order guide updated."
    else
      # Re-render the index in place rather than redirecting, so a rejected
      # rename (e.g. a duplicate name) keeps what the manager typed and shows
      # the error beside the field instead of dropping it to a top-of-page flash.
      # Matches the in-place recovery the create path already uses.
      load_guides_index
      @new_order_guide = OrderGuide.new
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    guide = OrderGuide.find(params[:id])
    guide.archive!

    redirect_to order_guides_path, notice: "Order guide archived."
  end

  private

  def load_guides_index
    @order_guides = OrderGuide.ordered.includes(:order_guide_sections, order_guide_memberships: [ :order_guide_section, { inventory_item: [ :inventory_section, :product ] } ])
    @missing_products = Purchasing::InventoryGapAnalyzer.new.missing_products(limit: 40)
  end

  def order_guide_params
    params.require(:order_guide).permit(:name, :notes, :active)
  end
end
