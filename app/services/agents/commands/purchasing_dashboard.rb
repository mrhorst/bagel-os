module Agents
  module Commands
    # Top-line purchasing KPIs: total spend, receipt/product counts, spend by
    # category and supplier, and how much is waiting on review. The numbers
    # behind the purchasing dashboard, without the charts.
    class PurchasingDashboard < Command
      command "purchasing:dashboard"
      summary "Purchasing KPIs: spend, counts, category/supplier breakdown"

      def call
        snapshot = Purchasing::PurchasingDashboardSnapshot.new.snapshot

        {
          total_spend: money(snapshot.total_spend),
          receipt_count: snapshot.receipt_count,
          product_count: snapshot.product_count,
          average_receipt_total: money(snapshot.average_receipt_total),
          category_spend: money_map(snapshot.category_spend),
          supplier_spend: money_map(snapshot.supplier_spend),
          needs_review_count: snapshot.needs_review.size,
          spike_count: snapshot.spikes.size
        }
      end

      private

      # category_spend is an array of [name, total] pairs; supplier_spend is a
      # hash. Normalize both to a name => money-string hash.
      def money_map(pairs)
        pairs.to_h.transform_values { |total| money(total) }
      end
    end
  end
end
