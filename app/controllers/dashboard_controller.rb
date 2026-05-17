class DashboardController < ApplicationController
  def index
    snapshot = price_intelligence.dashboard_snapshot
    @total_spend = snapshot.total_spend
    @receipt_count = snapshot.receipt_count
    @product_count = snapshot.product_count
    @average_receipt_total = snapshot.average_receipt_total
    @monthly_spend = snapshot.monthly_spend
    @category_spend = snapshot.category_spend
    @supplier_spend = snapshot.supplier_spend
    @top_by_frequency = snapshot.top_by_frequency
    @top_by_spend = snapshot.top_by_spend
    @recent_products = snapshot.recent_products
    @spikes = snapshot.spikes
    @missing_standard = snapshot.missing_standard
    @needs_review = snapshot.needs_review
    @pending_review_count = NormalizationReview.pending.count
    @guide_items_needing_review_count = OrderGuideItem.active.needs_review.count
    @inventory_items_needing_review_count = InventoryItem.active.needs_review.count
    gap_analyzer = Purchasing::InventoryGapAnalyzer.new
    @missing_products = gap_analyzer.missing_products(limit: 8)
    @gap_summary = gap_analyzer.summary
  end

  private

  def price_intelligence
    @price_intelligence ||= Purchasing::PriceIntelligence.new
  end
end
