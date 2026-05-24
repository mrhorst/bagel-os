class BackfillFollowUpsFromLogBook < ActiveRecord::Migration[8.1]
  # Backfill: every LogBookResponse that's currently flagged becomes a
  # FollowUp record. Status mirrors whether the response was already
  # resolved. Run-once data migration.
  def up
    log_book_response = Class.new(ActiveRecord::Base) { self.table_name = "log_book_responses" }
    follow_up        = Class.new(ActiveRecord::Base) { self.table_name = "follow_ups" }

    log_book_response.where(flagged_for_follow_up: true).find_each do |response|
      opened_at   = response.last_submitted_at || response.created_at
      resolved_at = response.follow_up_resolved_at

      follow_up.create!(
        origin_type:     "LogBookResponse",
        origin_id:       response.id,
        title:           response.section_title_snapshot.to_s,
        description:     response.value_text.presence,
        urgency:         response.urgency.presence || "normal",
        status:          resolved_at ? "resolved" : "open",
        opened_by_id:    response.last_submitted_by_id,
        opened_at:       opened_at,
        resolved_by_id:  response.follow_up_resolved_by_id,
        resolved_at:     resolved_at,
        created_at:      opened_at,
        updated_at:      resolved_at || opened_at
      )
    end
  end

  def down
    execute "DELETE FROM follow_ups WHERE origin_type = 'LogBookResponse'"
  end
end
