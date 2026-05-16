namespace :inventory do
  DEFAULT_ORDER_GUIDE_DIR = Rails.root.join(".private", "order_guides", "current").to_s

  desc "Import current daily/weekly order guide PDFs from ORDER_GUIDE_DIR or .private/order_guides/current"
  task import_order_guides: :environment do
    source_dir = ENV.fetch("ORDER_GUIDE_DIR", DEFAULT_ORDER_GUIDE_DIR)
    files = Dir.glob(File.join(source_dir, "*.pdf")).sort
    importer = Purchasing::OrderGuideImporter.new

    puts "Found #{files.size} order guide PDF files in #{source_dir}"
    imported = 0
    skipped = 0

    files.each do |path|
      result = importer.import_file(path)
      result.skipped ? skipped += 1 : imported += 1
      puts "#{File.basename(path)}: #{result.message}"
    end

    puts "Order guide import summary"
    puts "files imported: #{imported}"
    puts "files skipped: #{skipped}"
    puts "active guide rows: #{OrderGuideItem.active.count}"
    puts "inventory items: #{InventoryItem.active.count}"
    puts "guide rows needing review: #{OrderGuideItem.active.needs_review.count}"
    puts "receipt products not on guide: #{Purchasing::InventoryGapAnalyzer.new.missing_products.size}"
  end

  desc "Print receipt-backed products that are not covered by the current order guides"
  task guide_gaps: :environment do
    rows = Purchasing::InventoryGapAnalyzer.new.missing_products

    puts "Receipt products not on current guides: #{rows.size}"
    rows.each do |row|
      puts [
        row.product.canonical_name,
        row.product.category_name,
        "#{row.purchase_count} buys",
        ActionController::Base.helpers.number_to_currency(row.total_spend),
        row.classification
      ].join(" | ")
    end
  end

  desc "Refresh current order guide links after normalization rule changes"
  task refresh_order_guide_matches: :environment do
    stats = Purchasing::OrderGuideMatchRefresher.new.refresh!
    puts "Order guide match refresh"
    puts "rows reviewed: #{stats[:reviewed]}"
    puts "rows linked: #{stats[:linked]}"
    puts "guide rows needing review: #{OrderGuideItem.active.needs_review.count}"
    puts "receipt products not on guide: #{Purchasing::InventoryGapAnalyzer.new.missing_products.size}"
  end
end
