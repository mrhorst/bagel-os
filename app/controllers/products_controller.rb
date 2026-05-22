class ProductsController < ApplicationController
  include PriceChartHelper

  require_module_access :products

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
    @inventory_items = @product.inventory_items.active.includes(order_guide_memberships: :order_guide).ordered
    @order_guides = OrderGuide.active.ordered
    profile = price_intelligence.product_profile(@product, requested_chart_mode: params[:chart_mode])
    @stats = profile.stats
    @observations = profile.observations
    @variation_summaries = profile.variation_summaries
    @chart_mode = profile.chart_mode
    @chart_summaries = profile.chart_summaries
  end

  def edit
    @product = Product.includes(:product_category, :supplier, :product_aliases).find(params[:id])
    @categories = ProductCategory.ordered
    @receipt_line_count = @product.receipt_line_items.count
    @pending_line_review_count = @product.receipt_line_items.needs_review.count
    @alias_count = @product.product_aliases.count
  end

  def update
    @product = Product.find(params[:id])
    @product.assign_attributes(product_params)
    @product.needs_review = false if params[:mark_reviewed].present?

    if @product.save
      redirect_to @product, notice: "Product updated."
    else
      @categories = ProductCategory.ordered
      @receipt_line_count = @product.receipt_line_items.count
      @pending_line_review_count = @product.receipt_line_items.needs_review.count
      @alias_count = @product.product_aliases.count
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
