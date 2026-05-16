namespace :purchasing do
  DEFAULT_RECEIPT_SOURCE_DIR = Rails.root.join(".private", "receipts").to_s

  desc "Import all vendor receipt CSV files from SOURCE_DIR or .private/receipts"
  task import_all: :environment do
    source_dir = ENV.fetch("SOURCE_DIR", DEFAULT_RECEIPT_SOURCE_DIR)
    files = Dir.glob(File.join(source_dir, "*.csv")).sort
    importer = Purchasing::CsvImporter.new

    puts "Found #{files.size} CSV files in #{source_dir}"
    imported = 0
    skipped = 0

    files.each do |path|
      result = importer.import_file(path)
      result[:skipped] ? skipped += 1 : imported += 1
      puts "#{File.basename(path)}: #{result[:message]}"
    end

    puts "Validation summary"
    puts "total files found: #{files.size}"
    puts "total files imported: #{imported}"
    puts "total files skipped: #{skipped}"
    puts "total rows processed: #{ImportBatch.sum(:rows_processed)}"
    puts "total line items created: #{ReceiptLineItem.count}"
    puts "total products created: #{Product.count}"
    puts "total aliases created: #{ProductAlias.count}"
    puts "total price observations created: #{PriceObservation.count}"
    puts "total rows needing review: #{ReceiptLineItem.needs_review.count}"
    puts "total rows skipped: #{skipped_row_count}"
    puts "errors found: #{ImportBatch.where(status: 'failed').count}"
  end

  desc "Export purchasing reports to tmp/reports or REPORT_DIR"
  task export_reports: :environment do
    directory = ENV.fetch("REPORT_DIR", Rails.root.join("tmp", "reports").to_s)
    paths = Purchasing::ReportExporter.new.export_all(directory: directory)
    paths.each { |name, path| puts "#{name}: #{path}" }
  end

  desc "Rebuild price observations from receipt line items"
  task recalculate_price_observations: :environment do
    stats = Purchasing::ReceiptLineItemPriceRecalculator.new.recalculate_all!
    puts "Recalculated receipt line pricing and rebuilt price observations."
    stats.each { |key, value| puts "#{key}: #{value}" }
  end

  desc "Normalize raw supplier receipt names into simpler master products"
  task renormalize_products: :environment do
    stats = Purchasing::ProductCatalogNormalizer.new.normalize_all!
    puts "Product renormalization summary"
    stats.each { |key, value| puts "#{key}: #{value}" }
  end

  desc "Recalculate possible price spikes and review flags"
  task flag_reviews: :environment do
    Purchasing::PriceSpikeFlagger.new.flag_all!
    Product.find_each do |product|
      product.update!(needs_review: true) if product.product_category.blank? || product.product_category.name == "Other / unknown"
    end
    puts "Products needing review: #{Product.needs_review.count}"
    puts "Pending normalization reviews: #{NormalizationReview.pending.count}"
  end

  def skipped_row_count
    ImportBatch.pluck(:validation_summary).sum do |summary|
      summary.fetch("skipped_rows", summary.fetch(:skipped_rows, 0)).to_i
    end
  end
end
