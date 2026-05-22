class ReportsController < ApplicationController
  require_module_access :reports

  def index
    @reports = Purchasing::ReportExporter::REPORTS
  end

  def show
    report = params[:id]
    unless Purchasing::ReportExporter::REPORTS.include?(report)
      redirect_to reports_path, alert: "Unknown report."
      return
    end

    csv = report_csv(report)
    send_data csv, filename: "#{report}.csv", type: "text/csv"
  end

  private

  def report_csv(report)
    exporter = Purchasing::ReportExporter.new

    case report
    when "master_products" then exporter.master_products
    when "normalized_purchases" then exporter.normalized_purchases
    when "price_history" then exporter.price_history
    when "category_spend_summary" then exporter.category_spend_summary
    when "frequent_items" then exporter.frequent_items
    when "price_spike_alerts" then exporter.price_spike_alerts
    when "items_needing_review" then exporter.items_needing_review
    end
  end
end
