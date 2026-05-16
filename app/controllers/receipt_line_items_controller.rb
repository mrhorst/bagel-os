class ReceiptLineItemsController < ApplicationController
  def edit
    @line_item = find_line_item
    @case_pack = line_item_editor.case_pack_for(@line_item)
  end

  def update
    @line_item = find_line_item
    result = line_item_editor.update_case_pack(
      line_item: @line_item,
      attributes: case_pack_params
    )
    @case_pack = result.case_pack

    if result.success?
      redirect_to line_item_return_path(result.line_item), notice: "Purchase line updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_line_item
    ReceiptLineItem.includes(:receipt, :import_batch, :supplier, :product, :case_pack, :price_observation, :normalization_reviews).find(params[:id])
  end

  def line_item_editor
    @line_item_editor ||= Purchasing::ReceiptLineItemEditor.new
  end

  def case_pack_params
    params.require(:supplier_product_pack).permit(
      :units_per_case,
      :inner_unit_label,
      :inner_package_size,
      :inner_unit_of_measure,
      :standard_unit,
      :notes
    )
  end

  def line_item_return_path(line_item)
    anchor = "receipt_line_item_#{line_item.id}"
    if line_item.product
      product_path(line_item.product, anchor: anchor)
    else
      import_batch_path(line_item.import_batch, anchor: anchor)
    end
  end
end
