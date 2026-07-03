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

  # The editor is dual-origin — reached from the receipt review list (batch) and
  # from a product's purchase history — and both the save redirect and the Cancel
  # link must return the user to where they came from, not key off whether the
  # line happens to have a product. Each caller threads a discrete return_to
  # token, matched here against a whitelist (never a raw path):
  #
  #   • return_to=import_batch → the receipt, so a batch reviewer stays in the
  #     top-to-bottom flag cleanup instead of being ejected to a product page.
  #   • return_to=product (or no hint, with a matched product) → the product, the
  #     reasonable landing when you acted on one line from the product workspace.
  #
  # With no hint and no product, the receipt is the only sensible target. Older
  # links, bookmarks, and deep links keep the historical product-or-receipt
  # default, so nothing but the two explicit origins changes.
  def line_item_return_path(line_item)
    anchor = "receipt_line_item_#{line_item.id}"
    if params[:return_to] == "import_batch" || line_item.product.nil?
      import_batch_path(line_item.import_batch, anchor: anchor)
    else
      product_path(line_item.product, anchor: anchor)
    end
  end
  helper_method :line_item_return_path
end
