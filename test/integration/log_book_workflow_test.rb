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
    assert_match "18 bagels", response.body

    get log_book_path
    assert_response :success
    assert_select "article.decision-card h2", text: "Bagels Left", count: 0
  end

  test "future dates redirect back to today" do
    get log_book_path(date: (Date.current + 7).iso8601)
    assert_redirected_to log_book_path
    follow_redirect!
    assert_match(/open a future log book/, response.body)
  end

  test "next arrow disappears when viewing today" do
    LogBookSection.create!(title: "General Log", section_type: "long_text")
    get log_book_path
    assert_response :success
    assert_select "a[aria-label='Previous day']", count: 1
    assert_select "a[aria-label='Next day']", count: 0
    assert_select "span[aria-label='No next day']", count: 1
  end

  test "per-section authorship is tracked across two writers" do
    section_a = LogBookSection.create!(title: "General Log", section_type: "long_text", position: 1)
    section_b = LogBookSection.create!(title: "Maintenance", section_type: "long_text", position: 2)

    first_user = users(:one)
    second_user = users(:two)
    second_user.grant_module("log_book")

    patch log_book_path, params: {
      operating_date: Date.current.iso8601,
      responses: {
        section_a.id => { value_text: "Morning was steady.", no_note: "0", flagged_for_follow_up: "0", urgency: "normal" },
        section_b.id => { value_text: "Walk-in is humming.",  no_note: "0", flagged_for_follow_up: "0", urgency: "normal" }
      }
    }
    assert_redirected_to log_book_path(date: Date.current)

    sign_in_as(second_user)
    patch log_book_path, params: {
      operating_date: Date.current.iso8601,
      responses: {
        section_b.id => { value_text: "Walk-in is at 41 F now.", no_note: "0", flagged_for_follow_up: "0", urgency: "normal" }
      }
    }

    entry = LogBookEntry.sole
    morning = entry.log_book_responses.find_by!(log_book_section: section_a)
    walkin  = entry.log_book_responses.find_by!(log_book_section: section_b)

    assert_equal first_user, morning.last_submitted_by, "untouched section keeps original author"
    assert_equal second_user, walkin.last_submitted_by, "edited section moves to the new writer"
    assert_equal "Walk-in is at 41 F now.", walkin.value_text
  end

  test "section with allow_follow_up disabled ignores submitted urgency flag" do
    section = LogBookSection.create!(
      title: "Vendor reference",
      section_type: "short_text",
      allow_follow_up: false
    )

    patch log_book_path, params: {
      operating_date: Date.current.iso8601,
      responses: {
        section.id => { value_text: "Acme Bakery", no_note: "0", flagged_for_follow_up: "1", urgency: "urgent" }
      }
    }

    response = LogBookResponse.sole
    refute response.flagged_for_follow_up?
    assert_equal "normal", response.urgency
  end

  test "validation errors re-render the form with the user's input" do
    LogBookSection.create!(
      title: "Safe Count",
      section_type: "number",
      allow_no_note: false,
      required: true
    )

    patch log_book_path, params: {
      operating_date: Date.current.iso8601,
      responses: {
        LogBookSection.sole.id => { value_number: "", no_note: "0", flagged_for_follow_up: "0", urgency: "normal" }
      }
    }

    assert_response :unprocessable_entity
    assert_match "Value number is required", response.body
    assert_select "div.log-book-section-error p.log-book-card-error",
      text: /Value number is required/
  end

  test "required section without no-note option saves when no_note param is absent" do
    section = LogBookSection.create!(
      title: "Manager Notes",
      section_type: "long_text",
      allow_no_note: false,
      required: true
    )

    patch log_book_path, params: {
      operating_date: Date.current.iso8601,
      responses: {
        section.id => { value_text: "Hello", flagged_for_follow_up: "0", urgency: "normal" }
      }
    }

    assert_redirected_to log_book_path(date: Date.current)
    saved_response = LogBookResponse.find_by!(log_book_section: section)
    assert_equal "Hello", saved_response.value_text
    refute saved_response.no_note?
  end

  test "autosave returns a turbo stream with save status and meta updates" do
    section = LogBookSection.create!(title: "General Log", section_type: "long_text")

    patch log_book_path,
      params: {
        operating_date: Date.current.iso8601,
        responses: { section.id => { value_text: "Morning rush handled.", no_note: "0", flagged_for_follow_up: "0", urgency: "normal" } }
      },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.media_type + "; charset=utf-8"
    assert_match %Q(turbo-stream action="replace" target="log_book_save_status"), response.body
    assert_match %Q(turbo-stream action="replace" target="log_book_response_meta_#{section.id}"), response.body
    assert_match "Saved", response.body
  end

  test "recent entries row shows open follow-up signals per day" do
    section = LogBookSection.create!(title: "General Log", section_type: "long_text")
    yesterday = LogBookEntry.create!(operating_date: Date.yesterday)
    yesterday.log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_text: "Quiet day.",
      flagged_for_follow_up: true,
      urgency: "urgent"
    )

    get log_book_path
    assert_response :success
    assert_select "li.log-book-recent-row .badge", text: /1 follow-up/
    assert_select "li.log-book-recent-row .badge", text: /1 urgent/
  end

  test "archive button carries a confirmation that includes usage count" do
    section = LogBookSection.create!(title: "Bagels Left", section_type: "number")
    LogBookEntry.create!(operating_date: Date.current).log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_number: 12
    )

    get log_book_sections_path
    assert_response :success
    assert_select "form[action='#{archive_log_book_section_path(section)}'] button[data-turbo-confirm*='used in 1 entry']"
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
