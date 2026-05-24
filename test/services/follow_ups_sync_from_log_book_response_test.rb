require "test_helper"

class FollowUpsSyncFromLogBookResponseTest < ActiveSupport::TestCase
  setup do
    @user    = users(:one)
    @section = LogBookSection.create!(title: "Maintenance", section_type: "long_text", allow_follow_up: true)
    @entry   = LogBookEntry.create!(operating_date: Date.current)
  end

  test "creates an open follow-up when a response is flagged" do
    response = build_response(flagged: true, urgency: "urgent", text: "Toilet clogged")
    response.save!

    assert_difference -> { FollowUp.count }, 1 do
      FollowUps::SyncFromLogBookResponse.new(response, user: @user).call
    end

    follow_up = FollowUp.last
    assert_equal "Maintenance", follow_up.title
    assert_equal "Toilet clogged", follow_up.description
    assert_equal "urgent", follow_up.urgency
    assert follow_up.open?
    assert_equal @user, follow_up.opened_by
    assert_equal response, follow_up.origin
  end

  test "resolves the open follow-up when the response is no longer flagged" do
    response = build_response(flagged: true, text: "Bathroom leak")
    response.save!
    FollowUps::SyncFromLogBookResponse.new(response, user: @user).call

    response.update!(flagged_for_follow_up: false)
    FollowUps::SyncFromLogBookResponse.new(response, user: @user).call

    follow_up = FollowUp.last
    assert follow_up.resolved?
    assert_equal @user, follow_up.resolved_by
  end

  test "creates a new follow-up when a previously-resolved response is re-flagged" do
    response = build_response(flagged: true, text: "Walk-in warm")
    response.save!
    FollowUps::SyncFromLogBookResponse.new(response, user: @user).call

    response.update!(flagged_for_follow_up: false)
    FollowUps::SyncFromLogBookResponse.new(response, user: @user).call

    response.update!(flagged_for_follow_up: true)
    assert_difference -> { FollowUp.count }, 1 do
      FollowUps::SyncFromLogBookResponse.new(response, user: @user).call
    end
  end

  test "does nothing when the response was never flagged" do
    response = build_response(flagged: false, text: "Normal day")
    response.save!

    assert_no_difference -> { FollowUp.count } do
      FollowUps::SyncFromLogBookResponse.new(response, user: @user).call
    end
  end

  private

  def build_response(flagged:, urgency: "normal", text:)
    @entry.log_book_responses.build(
      log_book_section:       @section,
      section_title_snapshot: @section.title,
      section_type_snapshot:  @section.section_type,
      value_text:             text,
      flagged_for_follow_up:  flagged,
      urgency:                urgency,
      last_submitted_by:      @user,
      last_submitted_at:      Time.current
    )
  end
end
