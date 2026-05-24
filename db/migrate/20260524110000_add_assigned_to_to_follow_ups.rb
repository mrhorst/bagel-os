class AddAssignedToToFollowUps < ActiveRecord::Migration[8.1]
  def change
    add_reference :follow_ups, :assigned_to, foreign_key: { to_table: :users }
  end
end
