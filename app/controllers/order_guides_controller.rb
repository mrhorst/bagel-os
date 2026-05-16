class OrderGuidesController < ApplicationController
  CURRENT_GUIDE_DIR = Rails.root.join("data", "order_guides", "current")

  def index
    @imports = OrderGuideImport.recent_first.limit(10)
    @daily_items = OrderGuideItem.active.where(guide_type: "daily").ordered.includes(inventory_item: :product)
    @weekly_items = OrderGuideItem.active.where(guide_type: "weekly").ordered.includes(inventory_item: :product)
    @guide_items_needing_review = OrderGuideItem.active.needs_review.ordered.limit(30)
    @missing_products = Purchasing::InventoryGapAnalyzer.new.missing_products(limit: 40)
  end

  def import_current
    files = Dir.glob(CURRENT_GUIDE_DIR.join("*.pdf")).sort
    if files.empty?
      redirect_to order_guides_path, alert: "No PDF files found in #{CURRENT_GUIDE_DIR}."
      return
    end

    importer = Purchasing::OrderGuideImporter.new
    results = files.map { |path| importer.import_file(path) }
    imported = results.count { |result| !result.skipped }
    skipped = results.count(&:skipped)

    redirect_to order_guides_path, notice: "Order guide import complete: #{imported} imported, #{skipped} skipped."
  rescue Purchasing::OrderGuideTextExtractor::ExtractionError, ArgumentError => error
    redirect_to order_guides_path, alert: error.message
  end
end
