require "csv"

module Purchasing
  class ReportExporter
    REPORTS = %w[
      master_products
      normalized_purchases
      price_history
      category_spend_summary
      frequent_items
      price_spike_alerts
      items_needing_review
    ].freeze

    def initialize(price_intelligence: PriceIntelligence.new)
      @price_intelligence = price_intelligence
    end

    def export_all(directory: Rails.root.join("tmp", "reports"))
      FileUtils.mkdir_p(directory)
      REPORTS.index_with do |report|
        path = File.join(directory, "#{report}.csv")
        File.write(path, public_send(report))
        path
      end
    end

    def master_products
      CSV.generate(headers: true) do |csv|
        csv << %w[id canonical_name category supplier supplier_sku latest_price average_price lowest_price highest_price latest_standard_unit_price average_standard_unit_price total_times_purchased total_quantity_purchased total_spend first_purchase_date last_purchase_date needs_review]
        price_intelligence.master_product_rows.each { |row| csv << row }
      end
    end

    def normalized_purchases
      CSV.generate(headers: true) do |csv|
        csv << %w[receipt_number purchased_at product category raw_name raw_sku unit_quantity case_quantity purchase_kind quantity package_price inner_quantity inner_unit_price inner_unit_label presentation standard_quantity line_total standard_unit_price standard_unit source_filename needs_review]
        ReceiptLineItem.includes(:receipt, :product, :supplier, :import_batch, product: :product_category).order(:created_at).find_each do |line|
          csv << [
            line.receipt.receipt_number,
            line.receipt.purchased_at,
            line.product&.canonical_name,
            line.product&.category_name,
            line.raw_name,
            line.raw_sku,
            line.unit_quantity,
            line.case_quantity,
            line.purchase_kind,
            line.quantity,
            line.package_price,
            line.inner_quantity,
            line.inner_unit_price,
            line.inner_unit_label,
            line.price_observation&.presentation_label,
            line.price_observation&.standard_quantity,
            line.line_total,
            line.price_observation&.standard_unit_price,
            line.price_observation&.standard_unit,
            line.import_batch.source_filename,
            line.needs_review
          ]
        end
      end
    end

    def price_history
      CSV.generate(headers: true) do |csv|
        csv << %w[product supplier_sku observed_at presentation purchase_kind unit_quantity case_quantity package_price quantity inner_quantity inner_unit_price inner_unit_label standard_quantity line_total standard_unit_price standard_unit price_basis source_filename possible_price_spike]
        PriceObservation.includes(product: :product_aliases).chronological.find_each do |observation|
          csv << [
            observation.product.canonical_name,
            observation.product.supplier_sku_summary,
            observation.observed_at,
            observation.presentation_label,
            observation.purchase_kind,
            observation.unit_quantity,
            observation.case_quantity,
            observation.package_price,
            observation.quantity,
            observation.inner_quantity,
            observation.inner_unit_price,
            observation.inner_unit_label,
            observation.standard_quantity,
            observation.line_total,
            observation.standard_unit_price,
            observation.standard_unit,
            observation.price_basis,
            observation.source_filename,
            observation.possible_price_spike
          ]
        end
      end
    end

    def category_spend_summary
      CSV.generate(headers: true) do |csv|
        csv << %w[category total_spend product_count observation_count]
        ProductCategory.ordered.each do |category|
          observations = PriceObservation.joins(product: :product_category).where(products: { product_category_id: category.id })
          csv << [ category.name, observations.sum(:line_total), category.products.count, observations.count ]
        end
      end
    end

    def frequent_items
      CSV.generate(headers: true) do |csv|
        csv << %w[product category times_purchased total_spend last_purchased]
        price_intelligence.frequent_item_rows.each { |row| csv << row }
      end
    end

    def price_spike_alerts
      CSV.generate(headers: true) do |csv|
        csv << %w[product observed_at package_price percent_above_recent_average source_filename]
        PriceObservation.spikes.includes(:product).chronological.find_each do |observation|
          csv << [
            observation.product.canonical_name,
            observation.observed_at,
            observation.package_price,
            observation.percent_above_recent_average,
            observation.source_filename
          ]
        end
      end
    end

    def items_needing_review
      CSV.generate(headers: true) do |csv|
        csv << %w[issue_type status receipt_number raw_name raw_sku product description source_filename]
        NormalizationReview.includes(:product, receipt_line_item: [ :receipt, :import_batch ]).recent.find_each do |review|
          line = review.receipt_line_item
          csv << [
            review.issue_type,
            review.status,
            line.receipt.receipt_number,
            line.raw_name,
            line.raw_sku,
            review.product&.canonical_name || line.product&.canonical_name,
            review.description,
            line.import_batch.source_filename
          ]
        end
      end
    end

    private

    attr_reader :price_intelligence
  end
end
