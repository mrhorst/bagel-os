require "test_helper"

class LogBookSectionsControllerTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  setup do
    sign_in_as(users(:one)) # owner/admin — require_admin! gates this controller
  end

  test "non-admins are turned away" do
    sign_in_as(users(:two)) # role 0, non-admin

    get log_book_sections_path
    assert_redirected_to root_path
  end

  test "the new form defaults Sort order to the next position so a new section appends to the end" do
    # Two existing sections occupying positions 1 and 2.
    LogBookSection.create!(title: "General Log", section_type: "long_text", position: 1)
    LogBookSection.create!(title: "Maintenance", section_type: "long_text", position: 2)

    get new_log_book_section_path
    assert_response :success

    # The Sort order field must pre-fill with max(position)+1, not 0 — a 0 default
    # sorts the new section ABOVE every existing one in the daily Log Book.
    assert_select "input[name=?][value=?]", "log_book_section[position]", "3"
  end

  test "a section created from the new form lands at the end of the ordered list, not the top" do
    LogBookSection.create!(title: "General Log", section_type: "long_text", position: 1)
    LogBookSection.create!(title: "Maintenance", section_type: "long_text", position: 2)

    next_position = LogBookSection.maximum(:position) + 1
    assert_difference "LogBookSection.count", 1 do
      post log_book_sections_path, params: {
        log_book_section: { title: "Walk-in temp check", section_type: "number", position: next_position }
      }
    end
    assert_redirected_to log_book_sections_path

    # Appended at the end — the established "General Log" stays first.
    assert_equal "Walk-in temp check", LogBookSection.ordered.last.title
    assert_equal "General Log", LogBookSection.ordered.first.title
  end
end
