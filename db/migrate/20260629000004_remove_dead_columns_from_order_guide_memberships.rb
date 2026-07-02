class RemoveDeadColumnsFromOrderGuideMemberships < ActiveRecord::Migration[8.1]
  # par and reorder_point were added with the flexible order guides schema but
  # never read or written: memberships drive ordering from
  # expected_usage_quantity + buffer_quantity instead. Drop the unused columns.
  def change
    remove_column :order_guide_memberships, :par, :decimal, precision: 12, scale: 4
    remove_column :order_guide_memberships, :reorder_point, :decimal, precision: 12, scale: 4
  end
end
