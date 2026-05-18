require "csv"

class OrderGuidesController < ApplicationController
  CSV_EXAMPLE_HEADERS = %w[
    guide_name
    item_name
    section
    category
    count_unit
    pack_size
    primary_guide
    position
    notes
  ].freeze
  CSV_EXAMPLE_ROWS = [
    [ "Daily", "Eggs", "Walk-in cooler", "Eggs", "case", "case", "yes", "1", "Count before morning order." ],
    [ "Weekly", "Coffee beans", "Dry storage", "Coffee / tea", "bag", "bag", "yes", "2", "Use generic roast names." ],
    [ "Every 2 weeks", "To-go cups", "Paper and packaging", "Packaging", "sleeve", "case", "yes", "3", "Staff-facing names." ]
  ].freeze

  def index
    @order_guides = OrderGuide.ordered.includes(order_guide_memberships: { inventory_item: [ :inventory_section, :product ] })
    @missing_products = Purchasing::InventoryGapAnalyzer.new.missing_products(limit: 40)
  end

  def show
    @order_guide = OrderGuide
      .includes(order_guide_memberships: { inventory_item: [ :inventory_section, :product, :preferred_supplier ] })
      .find(params[:id])
    @memberships = @order_guide.order_guide_memberships
      .active
      .joins(:inventory_item)
      .includes(inventory_item: [ :inventory_section, :product, :preferred_supplier ])
      .order(:position, "inventory_items.name")
  end

  def create
    guide = OrderGuide.new(order_guide_params)
    guide.position = OrderGuide.maximum(:position).to_i + 1

    if guide.save
      redirect_to order_guides_path, notice: "Order guide created."
    else
      redirect_to order_guides_path, alert: guide.errors.full_messages.to_sentence
    end
  end

  def update
    guide = OrderGuide.find(params[:id])

    if guide.update(order_guide_params)
      redirect_to order_guides_path, notice: "Order guide updated."
    else
      redirect_to order_guides_path, alert: guide.errors.full_messages.to_sentence
    end
  end

  def destroy
    guide = OrderGuide.find(params[:id])
    guide.archive!

    redirect_to order_guides_path, notice: "Order guide archived."
  end

  def csv_example
    csv = CSV.generate(headers: true) do |output|
      output << CSV_EXAMPLE_HEADERS
      CSV_EXAMPLE_ROWS.each { |row| output << row }
    end

    send_data csv, filename: "order-guide-import-example.csv", type: "text/csv"
  end

  private

  def order_guide_params
    params.require(:order_guide).permit(:name, :notes, :active)
  end
end
