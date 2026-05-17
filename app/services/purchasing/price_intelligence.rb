module Purchasing
  class PriceIntelligence
    CHART_MODES = %w[standard_unit_price inner_unit_price package_price line_total quantity].freeze

    ProductProfile = Struct.new(
      :product,
      :stats,
      :observations,
      :variation_summaries,
      :chart_mode,
      :chart_summaries,
      keyword_init: true
    )

    DashboardSnapshot = Struct.new(
      :total_spend,
      :receipt_count,
      :product_count,
      :average_receipt_total,
      :monthly_spend,
      :category_spend,
      :supplier_spend,
      :top_by_frequency,
      :top_by_spend,
      :recent_products,
      :spikes,
      :missing_standard,
      :needs_review,
      keyword_init: true
    )

    def product_index(params)
      sorted_products(filtered_products(params), params)
        .includes(:supplier, :product_category, :product_aliases, :price_observations)
    end

    def product_profile(product, requested_chart_mode: nil)
      observations = product.price_observations.includes(receipt_line_item: [ :receipt, :import_batch, :normalization_reviews, :product ]).chronological

      ProductProfile.new(
        product: product,
        stats: price_stats(product),
        observations: observations,
        variation_summaries: variation_summaries(product),
        chart_mode: chart_mode(observations, requested: requested_chart_mode),
        chart_summaries: chart_summaries(observations)
      )
    end

    def dashboard_snapshot
      DashboardSnapshot.new(
        total_spend: PriceObservation.sum(:line_total),
        receipt_count: Receipt.count,
        product_count: Product.count,
        average_receipt_total: Receipt.average(:total),
        monthly_spend: monthly_spend,
        category_spend: category_spend,
        supplier_spend: PriceObservation.joins(:supplier).group("suppliers.name").sum(:line_total),
        top_by_frequency: Product.left_joins(:price_observations).group("products.id").order(Arel.sql("COUNT(price_observations.id) DESC")).limit(10),
        top_by_spend: Product.left_joins(:price_observations).group("products.id").order(Arel.sql("COALESCE(SUM(price_observations.line_total), 0) DESC")).limit(10),
        recent_products: Product.where(id: PriceObservation.order(observed_at: :desc).limit(25).pluck(:product_id).uniq).limit(10),
        spikes: PriceObservation.spikes.includes(:product).order(observed_at: :desc).limit(10),
        missing_standard: Product.left_joins(:price_observations).where(price_observations: { standard_unit_price: nil }).distinct.limit(10),
        needs_review: Product.needs_review.limit(10)
      )
    end

    def price_stats(product)
      observations = product.price_observations
      latest_standard_observation = observations.with_standard_unit_price.order(observed_at: :desc, id: :desc).first
      observed_prices = observations.to_a
      latest = latest_observation(product)
      {
        latest_price: equivalent_package_price(latest),
        average_price: average_equivalent_package_price(observed_prices),
        lowest_price: observed_prices.filter_map { |observation| equivalent_package_price(observation) }.min,
        highest_price: observed_prices.filter_map { |observation| equivalent_package_price(observation) }.max,
        latest_standard_unit_price: latest_standard_observation&.standard_unit_price,
        average_standard_unit_price: average_standard_unit_price(observed_prices),
        total_times_purchased: observations.count,
        total_quantity_purchased: observations.sum(:quantity),
        total_unit_quantity_purchased: observations.sum(:unit_quantity),
        total_case_quantity_purchased: observations.sum(:case_quantity),
        total_spend: observations.sum(:line_total),
        first_purchase_date: observations.minimum(:observed_at),
        last_purchase_date: observations.maximum(:observed_at)
      }
    end

    def latest_observation(product)
      product.price_observations.order(observed_at: :desc, id: :desc).first
    end

    def variation_summaries(product)
      product.receipt_line_items.items.includes(:receipt, :import_batch).order(:raw_name, :raw_sku).group_by do |line_item|
        [ line_item.raw_name, line_item.raw_sku ]
      end.map do |(raw_name, raw_sku), lines|
        latest_line = lines.max_by { |line| [ line.receipt.purchased_at || line.created_at, line.id ] }

        {
          raw_name: raw_name,
          raw_sku: raw_sku,
          purchases_count: lines.size,
          total_spend: lines.sum { |line| line.line_total.to_d },
          first_purchased_at: lines.map { |line| line.receipt.purchased_at }.compact.min,
          last_purchased_at: lines.map { |line| line.receipt.purchased_at }.compact.max,
          latest_package_price: latest_line&.package_price,
          package_label: package_label_for(latest_line),
          needs_review: lines.any?(&:needs_review?)
        }
      end.sort_by { |summary| summary[:raw_name].to_s }
    end

    def chart_summaries(observations)
      CHART_MODES.index_with do |mode|
        chart_observations = chart_observations_for_mode(observations, mode)
        comparable_change = chart_observations.map { |observation| observation.chart_unit_key(mode) }.uniq.one?
        {
          observations: chart_observations,
          insight: chart_insight(chart_observations, mode),
          recent_change: comparable_change ? price_change(chart_observations, mode) : nil,
          change_30_days: comparable_change ? window_change(chart_observations, mode, 30.days) : nil,
          change_60_days: comparable_change ? window_change(chart_observations, mode, 60.days) : nil,
          change_90_days: comparable_change ? window_change(chart_observations, mode, 90.days) : nil
        }
      end
    end

    def chart_mode(observations, requested: nil)
      return requested if CHART_MODES.include?(requested)
      return "standard_unit_price" if observations.any? { |observation| observation.standard_unit_price.present? }
      return "inner_unit_price" if observations.any? { |observation| observation.inner_unit_price.present? }

      "package_price"
    end

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

    def chart_observations_for_mode(observations, mode)
      chart_observations = observations.select { |observation| observation.chart_value(mode).present? }
      return chart_observations unless mode == "package_price"

      comparable_observations = chart_observations.select(&:presentation_chart_uses_comparable_unit?)
      comparable_observations.presence || chart_observations
    end

    def chart_insight(observations, mode)
      return unless mode == "package_price"

      latest_by_presentation = observations
        .select(&:presentation_chart_uses_comparable_unit?)
        .group_by(&:presentation_key)
        .values
        .filter_map { |series| series.max_by { |observation| [ observation.observed_at, observation.id ] } }
      return if latest_by_presentation.size < 2
      return if latest_by_presentation.map(&:standard_unit).uniq.many?

      sorted = latest_by_presentation.sort_by { |observation| observation.standard_unit_price.to_d }
      best = sorted.first
      next_best = sorted.second
      return if best.standard_unit_price.blank? || next_best.standard_unit_price.blank? || next_best.standard_unit_price.to_d.zero?

      savings = ((next_best.standard_unit_price.to_d - best.standard_unit_price.to_d) / next_best.standard_unit_price.to_d * 100).round(1)
      return if savings.zero?

      {
        kind: "presentation_value",
        best_label: best.presentation_label.presence || best.receipt_line_item.raw_name,
        best_price: best.standard_unit_price,
        comparison_label: next_best.presentation_label.presence || next_best.receipt_line_item.raw_name,
        comparison_price: next_best.standard_unit_price,
        unit: best.standard_unit,
        savings_percent: savings
      }
    end

    def filtered_products(params)
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

    def price_change(observations, mode)
      return if observations.size < 2

      first = observations.first.chart_value(mode)
      latest = observations.last.chart_value(mode)
      return if first.blank? || latest.blank? || first.to_d.zero?

      ((latest.to_d - first.to_d) / first.to_d * 100).round(1)
    end

    def equivalent_package_price(observation)
      return unless observation

      observation.inner_unit_price.presence || observation.package_price
    end

    def average_equivalent_package_price(observations)
      priced_observations = observations.filter do |observation|
        observation.line_total.present? && equivalent_package_quantity(observation).present?
      end
      return if priced_observations.empty?

      total_spend = priced_observations.sum { |observation| observation.line_total.to_d }
      total_packages = priced_observations.sum { |observation| equivalent_package_quantity(observation).to_d }
      return if total_packages.zero?

      (total_spend / total_packages).round(4)
    end

    def equivalent_package_quantity(observation)
      observation.inner_quantity.presence || observation.quantity
    end

    def average_standard_unit_price(observations)
      priced_observations = observations.filter do |observation|
        observation.line_total.present? &&
          observation.standard_quantity.present? &&
          observation.standard_unit.present?
      end
      return if priced_observations.empty?
      return if priced_observations.map(&:standard_unit).uniq.many?

      total_spend = priced_observations.sum { |observation| observation.line_total.to_d }
      total_standard_quantity = priced_observations.sum { |observation| observation.standard_quantity.to_d }
      return if total_standard_quantity.zero?

      (total_spend / total_standard_quantity).round(4)
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

    def package_label_for(line_item)
      return "n/a" unless line_item

      size = line_item.parsed_package_size
      unit = line_item.parsed_unit_of_measure
      return "n/a" if size.blank? && unit.blank?
      return unit if size.blank?
      return size.to_d.round(4).to_s("F").sub(/\.?0+$/, "") if unit.blank?

      "#{size.to_d.round(4).to_s('F').sub(/\.?0+$/, '')} #{unit}"
    end
  end
end
