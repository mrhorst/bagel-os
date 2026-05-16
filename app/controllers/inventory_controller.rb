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
    @sections = InventorySection.ordered.includes(inventory_items: [ :product, :preferred_supplier ])
    @unsectioned_items = InventoryItem.active.where(inventory_section_id: nil).ordered
    @items_needing_review = InventoryItem.active.needs_review.order(:name)
  end

  def shopping_list
    @recommendations = Purchasing::InventoryRecommendation.new.rows
    @buy_now = @recommendations.select { |row| row.status == "buy_now" }
    @not_counted = @recommendations.select { |row| row.status == "not_counted" }
  end

  def counts
    @counts = InventoryCount.recent_first.includes(:inventory_section, :inventory_count_lines).limit(30)
  end

  def new_count
    @sections = InventorySection.ordered.includes(inventory_items: :product)
  end

  def create_count
    raw_counts = params[:counts]
    count_values = raw_counts.respond_to?(:each_pair) ? raw_counts.each_pair.to_h : {}
    submitted_counts = count_values.select { |_item_id, value| value.present? }

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
end
