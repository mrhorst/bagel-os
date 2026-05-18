class InventoryController < ApplicationController
  def index
    @inventory_item_count = InventoryItem.active.count
    @linked_inventory_item_count = InventoryItem.active.where.not(product_id: nil).count
    @guide_item_count = OrderGuideItem.active.count
    @guide_items_needing_review = OrderGuideItem.active.needs_review.count
    @latest_count = InventoryCount.recent_first.first
    @missing_products = Purchasing::InventoryGapAnalyzer.new.missing_products(limit: 12)
    @recommendations = Purchasing::InventoryRecommendation.new.rows
    @buy_now = @recommendations.select { |row| row.status == "buy_now" }.first(12)
  end

  def items
    @order_guides = OrderGuide.active.ordered
    @sections = InventorySection.ordered.includes(inventory_items: [ :product, :preferred_supplier, order_guide_memberships: :order_guide ])
    @unsectioned_items = InventoryItem.active.where(inventory_section_id: nil).ordered.includes(order_guide_memberships: :order_guide)
    @items_needing_review = InventoryItem.active.needs_review.order(:name)
  end

  def shopping_list
    @order_guides = OrderGuide.active.ordered

    if params[:order_guide_id].present?
      @order_guide = OrderGuide.active.find(params[:order_guide_id])
      recommendation = Purchasing::OrderGuideRecommendation.new(@order_guide)
      @recommendations = recommendation.rows
      @buy_now = @recommendations.select { |row| row.status == "buy_now" }
      @not_counted = @recommendations.select { |row| row.status == "not_counted" }
      @setup_needed = @recommendations.select { |row| row.status == "setup_needed" }
      @order_only = @recommendations.select { |row| row.status == "order_only" }
    else
      @recommendations = Purchasing::InventoryRecommendation.new.rows
      @buy_now = @recommendations.select { |row| row.status == "buy_now" }
      @not_counted = @recommendations.select { |row| row.status == "not_counted" }
      @setup_needed = []
      @order_only = []
    end
  end

  def counts
    @counts = InventoryCount.recent_first.includes(:inventory_section, :order_guide, :inventory_count_lines).limit(30)
  end

  def new_count
    @order_guides = OrderGuide.active.ordered
    return if params[:order_guide_id].blank?

    @order_guide = OrderGuide.active.find(params[:order_guide_id])
    @memberships = counted_memberships_for(@order_guide)
  end

  def create_count
    if params[:order_guide_id].present?
      create_guide_count
    else
      create_legacy_count
    end
  end

  def update_primary_order_guide
    item = InventoryItem.find(params[:id])
    guide = OrderGuide.active.find_by(id: params[:order_guide_id].presence)
    item.assign_primary_order_guide!(guide)

    redirect_back fallback_location: inventory_items_path, notice: "Updated #{item.name} primary guide."
  end

  private

  def create_guide_count
    order_guide = OrderGuide.active.find(params[:order_guide_id])
    submitted_counts = submitted_count_values

    if submitted_counts.empty?
      redirect_to new_inventory_count_path(order_guide_id: order_guide.id), alert: "Enter at least one count before saving."
      return
    end

    memberships = order_guide.order_guide_memberships.active.counted.includes(:inventory_item).where(id: submitted_counts.keys)
    memberships_by_id = memberships.index_by { |membership| membership.id.to_s }
    inventory_count = nil

    ActiveRecord::Base.transaction do
      inventory_count = InventoryCount.create!(
        order_guide: order_guide,
        source: "manual",
        status: "completed",
        counted_at: Time.current,
        completed_at: Time.current,
        notes: params[:notes]
      )

      submitted_counts.each do |membership_id, value|
        membership = memberships_by_id.fetch(membership_id.to_s)
        inventory_count.inventory_count_lines.create!(
          order_guide_membership: membership,
          inventory_item: membership.inventory_item,
          quantity_on_hand: BigDecimal(value.to_s),
          unit: membership.inventory_item.count_unit
        )
      end
    end

    redirect_to inventory_shopping_list_path(order_guide_id: order_guide.id), notice: "Saved #{inventory_count.inventory_count_lines.count} #{order_guide.name} counts."
  rescue ArgumentError
    redirect_to new_inventory_count_path(order_guide_id: params[:order_guide_id]), alert: "One of the counts was not a valid number."
  rescue ActiveRecord::RecordNotFound, KeyError
    redirect_to new_inventory_count_path, alert: "Choose an active guide and countable guide rows."
  end

  def create_legacy_count
    submitted_counts = submitted_count_values

    if submitted_counts.empty?
      redirect_to new_inventory_count_path, alert: "Enter at least one count before saving."
      return
    end

    inventory_count = nil
    ActiveRecord::Base.transaction do
      inventory_count = InventoryCount.create!(
        source: "manual",
        status: "completed",
        counted_at: Time.current,
        completed_at: Time.current,
        notes: params[:notes]
      )

      submitted_counts.each do |item_id, value|
        item = InventoryItem.find(item_id)
        inventory_count.inventory_count_lines.create!(
          inventory_item: item,
          quantity_on_hand: BigDecimal(value.to_s),
          unit: item.count_unit
        )
      end
    end

    redirect_to inventory_counts_path, notice: "Saved #{inventory_count.inventory_count_lines.count} inventory counts."
  rescue ArgumentError
    redirect_to new_inventory_count_path, alert: "One of the counts was not a valid number."
  end

  def submitted_count_values
    raw_counts = params[:counts]
    count_values = raw_counts.respond_to?(:each_pair) ? raw_counts.each_pair.to_h : {}
    count_values.select { |_item_id, value| value.present? }
  end

  def counted_memberships_for(order_guide)
    order_guide
      .order_guide_memberships
      .active
      .counted
      .includes(:order_guide_section, inventory_item: :product)
      .to_a
      .sort_by { |membership| membership_sort_key(membership) }
  end

  def membership_sort_key(membership)
    section = membership.order_guide_section
    [
      section&.position || 999_999,
      section&.name.to_s,
      membership.position,
      membership.inventory_item.name
    ]
  end
end
