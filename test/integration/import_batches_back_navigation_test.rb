require "test_helper"

# The "Upload receipt CSV" page (import_batches/new) only declared a
# :mobile_left_action chevron back to Imports. That chevron renders inside
# .mobile-screen-header, which is display:none on desktop, so a desktop user who
# opened the upload form and changed their mind had no in-content way back — the
# form ended in a bare submit. Every sibling create/edit screen (collections,
# products, admin tags, log book sections) carries a form-footer Cancel; this
# asserts Upload receipt CSV now matches that convention while keeping the
# mobile chevron intact.
class ImportBatchesBackNavigationTest < ActionDispatch::IntegrationTest
  test "the upload page offers a desktop-visible way back to Imports, not only the mobile chevron" do
    get new_import_batch_path
    assert_response :success

    # The mobile-screen-header chevron is display:none on desktop, so the form
    # itself must carry an in-content escape. Assert a link back to Imports
    # exists OUTSIDE the mobile header and the global sidebar — a genuine
    # page-level affordance, matching collections/products/admin tags.
    body = Nokogiri::HTML(@response.body)
    body.css(".mobile-screen-header").remove
    body.css(".app-sidebar").remove
    assert body.css("a[href='#{import_batches_path}']").any?,
      "expected an in-content Back/Cancel link to Imports on the upload page"
  end

  test "the upload page still keeps its mobile back-chevron to Imports" do
    get new_import_batch_path
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", import_batches_path
  end
end
