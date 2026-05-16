class ProductsController < ApplicationController
  include PriceChartHelper

  def index
    @categories = ProductCategory.ordered
    @suppliers = Supplier.order(:name)
    @products = filtered_products
    @products = sorted_products(@products).includes(:supplier, :product_category, :product_aliases, :price_observations)
  end

  def show
    @product = Product.includes(:supplier, :product_category, :product_aliases).find(params[:id])
    @stats = @product.price_stats
    @observations = @product.price_observations.includes(:receipt_line_item).chronological
    @variation_summaries = @product.variation_summaries
    @chart_mode = chart_mode
    @chart_summaries = chart_summaries
  end

  def edit
    @product = Product.find(params[:id])
    @categories = ProductCategory.ordered
  end

  def update
    @product = Product.find(params[:id])
    if @product.update(product_params)
      redirect_to @product, notice: "Product updated."
    else
      @categories = ProductCategory.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def filtered_products
    products = Product.all
    products = products.where(product_category_id: params[:category_id]) if params[:category_id].present?
    products = products.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    products = products.where(needs_review: true) if params[:needs_review] == "1"
    products = products.where(product_category_id: nil) if params[:missing_category] == "1"
    products = products.left_joins(:price_observations).where(price_observations: { standard_unit_price: nil }).distinct if params[:no_standard_unit_price] == "1"
    products = products.where(id: PriceObservation.spikes.select(:product_id)) if params[:price_increased] == "1"
    if params[:q].present?
      query = "%#{Product.sanitize_sql_like(params[:q].to_s.downcase)}%"
      products = products.left_joins(:product_aliases)
        .where(
          "LOWER(products.canonical_name) LIKE :query OR LOWER(product_aliases.raw_name) LIKE :query OR LOWER(product_aliases.raw_sku) LIKE :query",
          query: query
        )
        .distinct
    end
    products
  end

  def sorted_products(products)
    case params[:sort]
    when "total_spend"
      products.left_joins(:price_observations).group("products.id").order(Arel.sql("COALESCE(SUM(price_observations.line_total), 0) DESC"))
    when "purchase_frequency", "frequently_purchased"
      products.left_joins(:price_observations).group("products.id").order(Arel.sql("COUNT(price_observations.id) DESC"))
    when "latest_purchase_date", "recently_purchased"
      products.left_joins(:price_observations).group("products.id").order(Arel.sql("MAX(price_observations.observed_at) DESC NULLS LAST"))
    when "highest_price_increase"
      products.left_joins(:price_observations).group("products.id").order(Arel.sql("MAX(price_observations.percent_above_recent_average) DESC NULLS LAST"))
    when "category"
      products.left_joins(:product_category).order("product_categories.name ASC NULLS LAST", :canonical_name)
    else
      products.order(:canonical_name)
    end
  end

  def product_params
    params.require(:product).permit(
      :canonical_name,
      :product_category_id,
      :purchase_unit,
      :package_size,
      :unit_of_measure,
      :standard_unit,
      :notes,
      :active,
      :needs_review
    )
  end

  def chart_summaries
    PriceChartHelper::CHART_MODES.keys.index_with do |mode|
      observations = @observations.select { |observation| observation.chart_value(mode).present? }
      comparable_change = observations.map { |observation| observation.chart_series_key(mode) }.uniq.one?
      {
        observations: observations,
        recent_change: comparable_change ? price_change(observations, mode) : nil,
        change_30_days: comparable_change ? window_change(observations, mode, 30.days) : nil,
        change_60_days: comparable_change ? window_change(observations, mode, 60.days) : nil,
        change_90_days: comparable_change ? window_change(observations, mode, 90.days) : nil
      }
    end
  end

  def chart_mode
    return params[:chart_mode] if PriceChartHelper::CHART_MODES.key?(params[:chart_mode])
    return "standard_unit_price" if @observations.any? { |observation| observation.standard_unit_price.present? }

    "package_price"
  end

  def price_change(observations, mode)
    return if observations.size < 2

    first = observations.first.chart_value(mode)
    latest = observations.last.chart_value(mode)
    return if first.blank? || latest.blank? || first.to_d.zero?

    ((latest.to_d - first.to_d) / first.to_d * 100).round(1)
  end

  def window_change(observations, mode, window)
    return if observations.size < 2

    latest = observations.last
    start_time = latest.observed_at - window
    starting_observation = observations.select { |observation| observation.observed_at >= start_time }.first
    return if starting_observation.blank? || starting_observation == latest

    first_value = starting_observation.chart_value(mode)
    latest_value = latest.chart_value(mode)
    return if first_value.blank? || latest_value.blank? || first_value.to_d.zero?

    ((latest_value.to_d - first_value.to_d) / first_value.to_d * 100).round(1)
  end
end
