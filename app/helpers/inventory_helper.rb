module InventoryHelper
  # The count input for one guide membership. Repopulates a prior submission's
  # value and flags rows whose value didn't parse, so a single bad entry no
  # longer wipes the whole count.
  def inventory_count_field(membership)
    id = membership.id.to_s
    number_field_tag "counts[#{id}]", @submitted_counts&.dig(id),
      min: 0, step: "any", inputmode: "decimal",
      "aria-invalid": (@invalid_count_ids&.include?(id) ? "true" : nil)
  end

  # The guide Buy List is reached from three origins: the Inventory index, an
  # Order Guide, and a saved Count. The two overshooting callers thread a
  # discrete return_to token (plus the count id where needed); this resolves it
  # to a known internal path server-side — never a raw URL — so a stale or forged
  # token, or a bare visit (bookmark, deep link, post-save-count redirect), falls
  # back to Inventory unchanged. Returns [path, aria_label, chevron_span] so the
  # mobile chevron and desktop back button always agree.
  def shopping_list_back_target(order_guide)
    case params[:return_to]
    when "order_guide"
      if order_guide
        [ order_guide_path(order_guide), "Back to order guide", "Guide" ]
      else
        inventory_back_target
      end
    when "count"
      count = InventoryCount.find_by(id: params[:count_id])
      count ? [ inventory_count_path(count), "Back to count", "Count" ] : inventory_back_target
    else
      inventory_back_target
    end
  end

  def inventory_back_target
    [ inventory_path, "Back to Inventory", "Inventory" ]
  end
end
