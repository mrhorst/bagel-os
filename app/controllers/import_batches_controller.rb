class ImportBatchesController < ApplicationController
  def index
    @import_batches = ImportBatch.includes(:supplier).recent
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

    redirect_to import_batches_path, notice: result[:message]
  end

  def show
    @import_batch = ImportBatch.includes(:supplier, :receipt).find(params[:id])
    @receipt = @import_batch.receipt
    @line_items = @import_batch.receipt_line_items.includes(:product).order(:line_number)
  end
end
