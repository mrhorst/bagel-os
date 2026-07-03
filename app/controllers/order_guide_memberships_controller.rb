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

    if order_guide
      # Re-render the guide page in place (instead of redirecting to a fresh GET
      # that wipes the form) so a recoverable mistake — most often submitting
      # without picking an item — keeps every other field the user typed. This is
      # the same input-preserving recovery OrderGuidesController#create/#update
      # already document for the guide-name form on the sibling screen. The Add
      # form isn't model-bound, so @membership_form carries the submitted values
      # back into the fields explicitly.
      flash.now[:alert] = alert
      @membership_form = membership_params
      load_guide_show_context(order_guide)
      render "order_guides/show", status: :unprocessable_entity
    else
      # No guide to return to (it was missing or archived), so the index is the
      # only sensible destination.
      redirect_to order_guides_path, alert: alert
    end
  end

  def update
    order_guide = OrderGuide.find(params[:order_guide_id])
    membership = order_guide.order_guide_memberships.active.find(params[:id])

    ActiveRecord::Base.transaction do
      section = order_guide.section_named!(membership_params[:section_name])
      attributes = {
        order_guide_section: section,
        tracking_mode: membership_params[:tracking_mode].presence || membership.tracking_mode,
        expected_usage_quantity: membership_params[:expected_usage_quantity],
        buffer_quantity: membership_params[:buffer_quantity]
      }
      # The inline row form edits setup fields only and carries no notes input;
      # the note is shown to staff on the buy list, so don't erase it on save.
      # Update notes only when the submitted form actually includes the field.
      attributes[:notes] = membership_params[:notes] if membership_params.key?(:notes)
      membership.update!(attributes)
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
  rescue ActiveRecord::RecordNotFound
    # The row is already gone — a double-tapped "×", a stale tab, or two staff
    # removing the same item. The user's intent (this item off the guide) is
    # already satisfied, so land them back on the guide with reassuring
    # feedback instead of a raw 404 dead-end, mirroring create/update above.
    redirect_to guide_or_index_path(order_guide), notice: "That item is already off #{order_guide&.name || "the guide"}."
  end

  private

  # Stay on the guide the user was editing when something fails, so a recoverable
  # mistake (e.g. submitting without picking an item) doesn't bounce them off to
  # the all-guides index and lose their place. Fall back to the index only when
  # the guide itself could not be found.
  def guide_or_index_path(order_guide)
    order_guide ? order_guide_path(order_guide) : order_guides_path
  end

  # Build the same instance variables OrderGuidesController#show renders, so a
  # failed add can re-render the guide page in place rather than redirecting.
  def load_guide_show_context(order_guide)
    @order_guide = order_guide
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
