class DashboardController < ApplicationController
  def index
    @total_spend = PriceObservation.sum(:line_total)
    @receipt_count = Receipt.count
    @product_count = Product.count
    @average_receipt_total = Receipt.average(:total)
    @monthly_spend = monthly_spend
    @category_spend = category_spend
    @supplier_spend = PriceObservation.joins(:supplier).group("suppliers.name").sum(:line_total)
    @top_by_frequency = Product.left_joins(:price_observations).group("products.id").order(Arel.sql("COUNT(price_observations.id) DESC")).limit(10)
    @top_by_spend = Product.left_joins(:price_observations).group("products.id").order(Arel.sql("COALESCE(SUM(price_observations.line_total), 0) DESC")).limit(10)
    @recent_products = Product.where(id: PriceObservation.order(observed_at: :desc).limit(25).pluck(:product_id).uniq).limit(10)
    @spikes = PriceObservation.spikes.includes(:product).order(observed_at: :desc).limit(10)
    @missing_standard = Product.left_joins(:price_observations).where(price_observations: { standard_unit_price: nil }).distinct.limit(10)
    @needs_review = Product.needs_review.limit(10)
  end

  private

  def category_spend
    PriceObservation
      .joins(product: :product_category)
      .group("product_categories.name")
      .sum(:line_total)
      .sort_by { |_name, total| -total.to_d }
  end

  def monthly_spend
    PriceObservation.order(:observed_at).group_by { |observation| observation.observed_at.beginning_of_month }.transform_values do |observations|
      observations.sum { |observation| observation.line_total.to_d }
    end
  end
end
