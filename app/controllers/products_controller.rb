class ProductsController < ApplicationController
  include PriceChartHelper

  def index
    @categories = ProductCategory.ordered
    @suppliers = Supplier.order(:name)
    @products = price_intelligence.product_index(params)
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
