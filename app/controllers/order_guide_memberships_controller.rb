class OrderGuideMembershipsController < ApplicationController
  def create
    order_guide = OrderGuide.active.find(params[:order_guide_id])
    inventory_item = InventoryItem.active.find(params[:inventory_item_id])
    inventory_item.add_to_order_guide!(order_guide, primary: false, position: next_position(order_guide))

    redirect_to order_guide_path(order_guide), notice: "#{inventory_item.name} added to #{order_guide.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to order_guides_path, alert: "Choose an active guide and inventory item."
  end

  def destroy
    order_guide = OrderGuide.find(params[:order_guide_id])
    membership = order_guide.order_guide_memberships.active.find(params[:id])
    item_name = membership.inventory_item.name
    membership.deactivate!

    redirect_to order_guide_path(order_guide), notice: "#{item_name} removed from #{order_guide.name}."
  end

  private

  def next_position(order_guide)
    order_guide.order_guide_memberships.active.maximum(:position).to_i + 1
  end
end
