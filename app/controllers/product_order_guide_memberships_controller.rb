class ProductOrderGuideMembershipsController < ApplicationController
  def create
    product = Product.includes(:supplier, :product_category).find(params[:product_id])
    guide = OrderGuide.active.find(product_membership_params[:order_guide_id])
    inventory_item = inventory_item_for(product)

    membership = nil
    ActiveRecord::Base.transaction do
      section = guide.section_named!(product_membership_params[:section_name])
      inventory_item.assign_attributes(
        name: product_membership_params[:item_name].presence || inventory_item.name.presence || product.canonical_name,
        product: product,
        preferred_supplier: inventory_item.preferred_supplier || product.supplier,
        category: inventory_item.category.presence || product.category_name,
        count_unit: product_membership_params[:count_unit].presence || inventory_item.count_unit,
        pack_size: product_membership_params[:pack_size].presence || inventory_item.pack_size,
        active: true,
        needs_review: false
      )
      inventory_item.save!

      membership = inventory_item.add_to_order_guide!(
        guide,
        primary: inventory_item.primary_order_guide.blank?,
        position: next_position(guide),
        notes: product_membership_params[:notes],
        order_guide_section: section,
        tracking_mode: product_membership_params[:tracking_mode].presence || "counted",
        expected_usage_quantity: product_membership_params[:expected_usage_quantity],
        buffer_quantity: product_membership_params[:buffer_quantity],
        preferred_supplier: product.supplier
      )
    end

    redirect_to add_to_guide_success_path(guide), notice: "#{membership.inventory_item.name} added to #{guide.name}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    # This "Add to guide" form is rendered from two places: the product show
    # page AND the order-guides index gap list ("Receipt Products Not On Current
    # Guides"). On failure, return the user to the page they were actually on —
    # a recoverable mistake (e.g. forgetting to pick a guide) shouldn't bounce
    # someone working the index gap list onto a product page they never asked to
    # see. Fall back to the product page when there's no usable referrer. This
    # mirrors the sibling OrderGuideMembershipsController, which deliberately
    # stays on the originating page so the user doesn't lose their place.
    redirect_back fallback_location: product_path(params[:product_id]), alert: membership_failure_message(error)
  end

  private

  # This "Add to guide" form is rendered from two callers, and success should
  # honor where the user came from — the same dual-origin intent the failure path
  # already encodes:
  #
  #   • Gap list (order-guides index): the user is clearing a batch of off-guide
  #     products, so stay on the gap list (now one row shorter) instead of
  #     ejecting to a single guide on every add.
  #   • Product workspace (default, no hint): landing on the guide is the
  #     reasonable confirmation that the product joined it.
  #
  # The gap-list caller threads return_to=gap_list, matched here against a
  # whitelist and mapped to a known internal path — never a raw URL — so a stale
  # or forged value simply falls back to the guide.
  def add_to_guide_success_path(guide)
    if params[:return_to] == "gap_list"
      order_guides_path(anchor: "guide-gaps")
    else
      order_guide_path(guide)
    end
  end

  # Keep the failure feedback human. A missing/blank guide selection is the common
  # mistake (the select defaults to its "Choose guide" prompt), so name the fix
  # instead of leaking a raw "Couldn't find OrderGuide with 'id'=..." message —
  # mirroring the friendly guard the sibling OrderGuideMembershipsController uses.
  def membership_failure_message(error)
    return "Choose a guide to add this product to." if product_membership_params[:order_guide_id].blank?
    return "That guide is no longer available — pick an active guide." if error.is_a?(ActiveRecord::RecordNotFound)

    error.message
  end

  def product_membership_params
    params.require(:membership).permit(
      :order_guide_id,
      :section_name,
      :item_name,
      :count_unit,
      :pack_size,
      :tracking_mode,
      :expected_usage_quantity,
      :buffer_quantity,
      :notes
    )
  end

  def inventory_item_for(product)
    product.inventory_items.first || InventoryItem.new(key: unique_inventory_key(product))
  end

  def unique_inventory_key(product)
    base_key = InventoryItem.key_for(product.canonical_name)
    existing_item_ids = product.inventory_items.pluck(:id)
    key_taken = InventoryItem.where(key: base_key).where.not(id: existing_item_ids).exists?
    return base_key unless key_taken

    "#{base_key}-product-#{product.id}"
  end

  def next_position(guide)
    guide.order_guide_memberships.active.maximum(:position).to_i + 1
  end
end
