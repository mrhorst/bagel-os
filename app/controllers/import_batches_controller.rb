class ImportBatchesController < ApplicationController
  require_module_access :import_batches

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
