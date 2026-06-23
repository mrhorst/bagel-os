require "csv"

class ImportBatchesController < ApplicationController
  require_module_access :import_batches

  # A receipt CSV is not a plain table: the parser keys off a header preamble, an
  # "Invoice:" line, an exact "UPC,Description,Unit Qty,Case Qty,Price" item header,
  # and totals encoded as UPC=0 rows (see Purchasing::ReceiptCsvParser). Without a
  # sample to copy, a first upload almost always fails on "Could not find expected
  # receipt item header." This example mirrors that contract with generic data, the
  # same way the order-guide import offers a downloadable example.
  CSV_EXAMPLE_PREAMBLE = [
    [ "Primary Supplier", nil, "Customer #0000000000" ],
    [ "100 Example Ave", nil, "Demo Restaurant" ],
    [ "Example City, ST 00000", nil, "1 Demo Way" ],
    [],
    [ "Invoice: 100001", "Terminal: 01", "2026/06/01 09:15 am" ]
  ].freeze

  CSV_EXAMPLE_ITEM_HEADER = [ "UPC", "Description", "Unit Qty", "Case Qty", "Price" ].freeze

  CSV_EXAMPLE_ROWS = [
    [ "000000000001", "All-purpose flour 50 lb bag", "2", "0", "$27.00" ],
    [ "000000000002", "Whole milk 4 x 1 gal", "0", "1", "$32.50" ],
    [ "000000000003", "(Coupon) Case rebate", "0", "1", "$0.00" ],
    [ "0", "Sub-Total", "0", "0", "$86.50" ],
    [ "0", "Tax", "0", "0", "$0.00" ],
    [ "0", "Total", "0", "0", "$86.50" ]
  ].freeze

  def index
    @import_batches = ImportBatch.includes(:supplier).recent
    # A batch can finish "imported" yet still leave lines flagged for review.
    # The post-import flash is transient, so surface the pending count on the
    # index too — otherwise an unfinished import looks done once the flash is
    # gone. Grouped count keeps this to one query instead of N.
    @review_counts = ReceiptLineItem.needs_review
                                     .where(import_batch_id: @import_batches.map(&:id))
                                     .group(:import_batch_id)
                                     .count
  end

  def new
  end

  def create
    uploaded_file = params[:csv_file]

    unless uploaded_file
      redirect_to new_import_batch_path, alert: "Choose a vendor receipt CSV file first."
      return
    end

    result = Purchasing::CsvImporter.new.import_file(
      uploaded_file.tempfile.path,
      source_filename: uploaded_file.original_filename
    )

    batch = result[:batch]
    if batch&.status == "failed"
      # A failed import isn't a success — report it as such and land on the
      # batch, where the failure reason and a recovery link are shown.
      redirect_to import_batch_path(batch), alert: result[:message]
    else
      redirect_to import_batches_path, notice: success_notice(result, batch)
    end
  end

  def show
    @import_batch = ImportBatch.includes(:supplier, :receipt).find(params[:id])
    @receipt = @import_batch.receipt
    @line_items = @import_batch.receipt_line_items.includes(:product).order(:line_number)
  end

  def csv_example
    csv = CSV.generate do |output|
      CSV_EXAMPLE_PREAMBLE.each { |row| output << row }
      output << CSV_EXAMPLE_ITEM_HEADER
      CSV_EXAMPLE_ROWS.each { |row| output << row }
    end

    send_data csv, filename: "receipt-import-example.csv", type: "text/csv"
  end

  private

  # A clean import still leaves work behind: some lines couldn't be matched with
  # confidence and are flagged for review. The success notice is the only cue the
  # user gets before landing back on the index (which has no review column), so
  # tell them how many lines need attention — otherwise the import looks "done"
  # when it isn't. Skipped re-imports (already imported by checksum/receipt) made
  # no new lines, so they get the plain message.
  def success_notice(result, batch)
    message = result[:message]
    return message if result[:skipped] || batch.blank?

    review_count = batch.receipt_line_items.needs_review.count
    return message unless review_count.positive?

    "#{message} #{review_count} #{'line'.pluralize(review_count)} #{review_count == 1 ? 'needs' : 'need'} review."
  end
end
