class ProductsController < ApplicationController
  include PriceChartHelper

  PRODUCTS_PER_PAGE_OPTIONS = [ 25, 50, 100 ].freeze
  DEFAULT_PRODUCTS_PER_PAGE = 50

  def index
    @categories = ProductCategory.ordered
    @suppliers = Supplier.order(:name)
    @per_page = products_per_page
    @page = products_page
    @products_scope = price_intelligence.product_index(params)
    @total_products = relation_count(@products_scope)
    @total_pages = [ (@total_products.to_f / @per_page).ceil, 1 ].max
    @page = @total_pages if @page > @total_pages
    @products = @products_scope.limit(@per_page).offset((@page - 1) * @per_page)
  end

  def show
    @product = Product.includes(:supplier, :product_category, :product_aliases).find(params[:id])
    profile = price_intelligence.product_profile(@product, requested_chart_mode: params[:chart_mode])
    @stats = profile.stats
    @observations = profile.observations
    @variation_summaries = profile.variation_summaries
    @chart_mode = profile.chart_mode
    @chart_summaries = profile.chart_summaries
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

  def price_intelligence
    @price_intelligence ||= Purchasing::PriceIntelligence.new
  end

  def products_per_page
    requested = params[:per_page].to_i
    return requested if PRODUCTS_PER_PAGE_OPTIONS.include?(requested)

    DEFAULT_PRODUCTS_PER_PAGE
  end

  def products_page
    [ params[:page].to_i, 1 ].max
  end

  def relation_count(relation)
    count = relation.except(:includes, :preload, :eager_load, :limit, :offset).count
    count.is_a?(Hash) ? count.size : count
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
end
