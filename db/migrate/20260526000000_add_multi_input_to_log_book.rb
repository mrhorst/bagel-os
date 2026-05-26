class AddMultiInputToLogBook < ActiveRecord::Migration[8.1]
  def change
    # JSON column on sections holding the sub-field configuration for
    # multi-input sections (e.g. one row per bagel type). Each entry:
    #   { "key" => "plain", "label" => "Plain", "type" => "number",
    #     "unit_label" => "bagels", "value_decimals" => 0 }
    add_column :log_book_sections, :fields, :text

    # Per-response storage for multi-input sections:
    #   value_grid     — { "plain" => "24", "sesame" => "12" }
    #   fields_snapshot — copy of section.fields at save time, so historic
    #                    rendering stays stable when labels change later.
    add_column :log_book_responses, :value_grid, :text
    add_column :log_book_responses, :fields_snapshot, :text
  end
end
