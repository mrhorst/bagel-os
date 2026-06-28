module Purchasing
  class PriceIntelligence
    CHART_MODES = ProductPriceProfile::CHART_MODES

    def initialize(product_profile: ProductPriceProfile.new, dashboard_snapshot: PurchasingDashboardSnapshot.new)
      @product_profile_reader = product_profile
      @dashboard_snapshot_reader = dashboard_snapshot
    end

    def product_index(params)
      sorted_products(filtered_products(params), params)
        .includes(:supplier, :product_category, :product_aliases, :price_observations)
    end

    def product_profile(product, requested_chart_mode: nil)
      product_profile_reader.profile(product, requested_chart_mode: requested_chart_mode)
    end

    def dashboard_snapshot
      dashboard_snapshot_reader.snapshot
    end

    def price_stats(product)
      product_profile_reader.price_stats(product)
    end

    def latest_observation(product)
      product_profile_reader.latest_observation(product)
    end

    def variation_summaries(product)
      product_profile_reader.variation_summaries(product)
    end

    def chart_summaries(observations)
      product_profile_reader.chart_summaries(observations)
    end

    def chart_mode(observations, requested: nil)
      product_profile_reader.chart_mode(observations, requested: requested)
    end

    # The Master products CSV is the complete receipt-backed history of record,
    # so it intentionally still includes products hidden from the in-app catalog
    # (active: false) — hiding only narrows the in-app browse/search, not exports.
    def master_product_rows
      Product.includes(:supplier, :product_category, :product_aliases, :price_observations).by_name.map do |product|
        stats = price_stats(product)
        [
          product.id,
          product.canonical_name,
          product.category_name,
          product.supplier.name,
          product.supplier_sku_summary,
          stats[:latest_price],
          stats[:average_price],
          stats[:lowest_price],
          stats[:highest_price],
          stats[:latest_standard_unit_price],
          stats[:average_standard_unit_price],
          stats[:total_times_purchased],
          stats[:total_quantity_purchased],
          stats[:total_spend],
          stats[:first_purchase_date],
          stats[:last_purchase_date],
          product.needs_review
        ]
      end
    end

    def frequent_item_rows(limit: 100)
      Product.left_joins(:price_observations).group("products.id").order(Arel.sql("COUNT(price_observations.id) DESC")).limit(limit).map do |product|
        stats = price_stats(product)
        [ product.canonical_name, product.category_name, stats[:total_times_purchased], stats[:total_spend], stats[:last_purchase_date] ]
      end
    end

    private

    attr_reader :product_profile_reader, :dashboard_snapshot_reader

    def filtered_products(params)
      products = Product.all
      products = filter_by_visibility(products, params)
      products = filter_by_category(products, params)
      products = filter_by_supplier(products, params)
      products = filter_by_review_state(products, params)
      products = filter_by_standard_unit_gap(products, params)
      products = filter_by_price_spike(products, params)
      products = filter_by_search(products, params)
      products
    end

    # The catalog hides products a manager unchecked "Visible in purchase
    # catalog" on (active: false), so it reads as the current purchasing list,
    # not the full receipt-backed history. "Show hidden" brings them back so a
    # hidden product is never stranded.
    def filter_by_visibility(products, params)
      return products if params[:show_hidden] == "1"

      products.active
    end

    def filter_by_category(products, params)
      products = products.where(product_category_id: params[:category_id]) if params[:category_id].present?
      products = products.where(product_category_id: nil) if params[:missing_category] == "1"
      products
    end

    def filter_by_supplier(products, params)
      return products unless params[:supplier_id].present?

      products.where(supplier_id: params[:supplier_id])
    end

    def filter_by_review_state(products, params)
      return products unless params[:needs_review] == "1"

      products.where(needs_review: true)
    end

    def filter_by_standard_unit_gap(products, params)
      return products unless params[:no_standard_unit_price] == "1"

      products.left_joins(:price_observations).where(price_observations: { standard_unit_price: nil }).distinct
    end

    def filter_by_price_spike(products, params)
      return products unless params[:price_increased] == "1"

      products.where(id: PriceObservation.spikes.select(:product_id))
    end

    def filter_by_search(products, params)
      return products unless params[:q].present?

      query = "%#{Product.sanitize_sql_like(params[:q].to_s.downcase)}%"
      products.left_joins(:product_aliases)
        .where(
          "LOWER(products.canonical_name) LIKE :query OR LOWER(product_aliases.raw_name) LIKE :query OR LOWER(product_aliases.raw_sku) LIKE :query",
          query: query
        )
        .distinct
    end

    def sorted_products(products, params)
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
  end
end
