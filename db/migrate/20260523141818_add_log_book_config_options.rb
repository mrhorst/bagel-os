class AddLogBookConfigOptions < ActiveRecord::Migration[8.1]
  def change
    # Section-level configuration knobs surfaced in the admin form.
    add_column :log_book_sections, :allow_follow_up, :boolean, null: false, default: true
    add_column :log_book_sections, :value_decimals, :integer, null: false, default: 0

    # Per-response authorship so two managers can fill out independently and
    # we can show "last touched by X at Y" against each section. Distinct from
    # the entry-level submitted_by, which still records who last hit save.
    add_reference :log_book_responses, :last_submitted_by,
                  foreign_key: { to_table: :users }
    add_column :log_book_responses, :last_submitted_at, :datetime

    # Snapshot of the section's value_decimals at the time the response was
    # saved — keeps historical entries stable if an admin changes precision.
    add_column :log_book_responses, :value_decimals_snapshot, :integer
  end
end
