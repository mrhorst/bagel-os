class OrderGuideMembershipsController < ApplicationController
  def create
    order_guide = OrderGuide.active.find(params[:order_guide_id])
    inventory_item = InventoryItem.active.find(membership_inventory_item_id)

    ActiveRecord::Base.transaction do
      section = order_guide.section_named!(membership_params[:section_name])
      inventory_item.add_to_order_guide!(
        order_guide,
        primary: false,
        position: next_position(order_guide),
        notes: membership_params[:notes],
        order_guide_section: section,
        tracking_mode: membership_params[:tracking_mode].presence || "counted",
        expected_usage_quantity: membership_params[:expected_usage_quantity],
        buffer_quantity: membership_params[:buffer_quantity]
      )
    end

    redirect_to order_guide_path(order_guide), notice: "#{inventory_item.name} added to #{order_guide.name}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    alert =
      if membership_inventory_item_id.blank?
        "Choose an inventory item to add to this guide."
      else
        error.message.presence || "Choose an active guide and inventory item."
      end
    redirect_to guide_or_index_path(order_guide), alert: alert
  end

  def update
    order_guide = OrderGuide.find(params[:order_guide_id])
    membership = order_guide.order_guide_memberships.active.find(params[:id])

    ActiveRecord::Base.transaction do
      section = order_guide.section_named!(membership_params[:section_name])
      membership.update!(
        order_guide_section: section,
        tracking_mode: membership_params[:tracking_mode].presence || membership.tracking_mode,
        expected_usage_quantity: membership_params[:expected_usage_quantity],
        buffer_quantity: membership_params[:buffer_quantity],
        notes: membership_params[:notes]
      )
    end

    redirect_to order_guide_path(order_guide), notice: "#{membership.inventory_item.name} guide setup updated."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to guide_or_index_path(order_guide), alert: error.message.presence || "Could not update this guide row."
  end

  def destroy
    order_guide = OrderGuide.find(params[:order_guide_id])
    membership = order_guide.order_guide_memberships.active.find(params[:id])
    item_name = membership.inventory_item.name
    membership.deactivate!

    redirect_to order_guide_path(order_guide), notice: "#{item_name} removed from #{order_guide.name}."
  end

  private

  # Stay on the guide the user was editing when something fails, so a recoverable
  # mistake (e.g. submitting without picking an item) doesn't bounce them off to
  # the all-guides index and lose their place. Fall back to the index only when
  # the guide itself could not be found.
  def guide_or_index_path(order_guide)
    order_guide ? order_guide_path(order_guide) : order_guides_path
  end

  def membership_params
    return ActionController::Parameters.new.permit if params[:membership].blank?

    params.require(:membership).permit(
      :inventory_item_id,
      :section_name,
      :tracking_mode,
      :expected_usage_quantity,
      :buffer_quantity,
      :notes
    )
  end

  def membership_inventory_item_id
    membership_params[:inventory_item_id].presence || params[:inventory_item_id]
  end

  def next_position(order_guide)
    order_guide.order_guide_memberships.active.maximum(:position).to_i + 1
  end
end
