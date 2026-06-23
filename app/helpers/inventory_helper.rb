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
end
