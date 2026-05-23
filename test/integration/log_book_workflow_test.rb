require "test_helper"

class LogBookWorkflowTest < ActionDispatch::IntegrationTest
  test "admin configures sections and anyone with access writes today's entry" do
    get log_book_sections_path
    assert_response :success

    assert_difference -> { LogBookSection.count } => 1 do
      post log_book_sections_path, params: {
        log_book_section: {
          title: "Maintenance",
          description: "Repairs and facility issues.",
          section_type: "long_text",
          position: 1,
          allow_no_note: "1"
        }
      }
    end

    section = LogBookSection.find_by!(title: "Maintenance")
    employee = users(:two)
    employee.grant_module("log_book")
    sign_in_as(employee)

    patch log_book_path, params: {
      operating_date: Time.zone.today.iso8601,
      responses: {
        section.id => {
          value_text: "Men's room toilet is clogged.",
          no_note: "0",
          flagged_for_follow_up: "1",
          urgency: "urgent"
        }
      }
    }

    assert_redirected_to log_book_path(date: Time.zone.today)
    response = LogBookResponse.find_by!(log_book_section: section)
    assert_equal "Men's room toilet is clogged.", response.value_text
    assert response.flagged_for_follow_up?
    assert_equal "urgent", response.urgency
    assert_equal employee, response.log_book_entry.submitted_by
  end

  test "past entries are readable but not editable" do
    section = LogBookSection.create!(title: "General Log", section_type: "long_text")
    LogBookSection.create!(title: "New Today", section_type: "long_text")
    entry = LogBookEntry.create!(operating_date: Date.yesterday)
    entry.log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_text: "Yesterday was busy."
    )

    get log_book_path(date: Date.yesterday)
    assert_response :success
    assert_match "Past operating days are read-only.", response.body
    assert_match "Yesterday was busy.", response.body
    refute_match "New Today", response.body

    patch log_book_path, params: {
      operating_date: Date.yesterday.iso8601,
      responses: {
        section.id => {
          value_text: "Changed after the fact.",
          no_note: "0",
          flagged_for_follow_up: "0",
          urgency: "normal"
        }
      }
    }

    assert_redirected_to log_book_path(date: Date.yesterday)
    assert_equal "Yesterday was busy.", entry.log_book_responses.first.reload.value_text
  end

  test "archived sections stay visible on old entries but disappear from today's form" do
    section = LogBookSection.create!(title: "Bagels Left", section_type: "number", unit_label: "bagels")
    entry = LogBookEntry.create!(operating_date: Date.yesterday)
    entry.log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_number: 18
    )

    patch archive_log_book_section_path(section)
    assert_redirected_to log_book_sections_path

    get log_book_path(date: Date.yesterday)
    assert_response :success
    assert_match "Bagels Left", response.body
    assert_match "18.0", response.body

    get log_book_path
    assert_response :success
    assert_select "article.decision-card h2", text: "Bagels Left", count: 0
  end

  test "admin resolves flagged follow-ups" do
    section = LogBookSection.create!(title: "Follow-ups", section_type: "long_text")
    entry = LogBookEntry.create!(operating_date: Date.current)
    follow_up = entry.log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_text: "Call plumber.",
      flagged_for_follow_up: true,
      urgency: "important"
    )

    patch resolve_log_book_response_path(follow_up)

    assert_redirected_to log_book_path
    assert follow_up.reload.follow_up_resolved_at.present?
    assert_equal users(:one), follow_up.follow_up_resolved_by
  end
end
