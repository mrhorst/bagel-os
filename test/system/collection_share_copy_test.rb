require "application_system_test_case"

# The collection share panel's whole purpose is to hand a public link to someone
# outside the app, so copying that link is the primary action once it exists.
# Before the clipboard controller the only affordance was a readonly field the
# user had to select and copy by hand — no Copy button at all. These tests pin
# the one-tap Copy button and its visible confirmation so the affordance can't
# quietly regress back to select-it-yourself.
class CollectionShareCopyTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "the share panel offers a one-tap Copy button that confirms it copied" do
    collection = collections(:summer)
    collection.shares.create! # an active share so the link row renders

    visit collection_path(collection)

    within ".share-link-row" do
      assert_selector "button", text: "Copy"
      click_on "Copy"
      # The confirmation fires regardless of which copy path ran, so it's the
      # reliable signal that the button did something.
      assert_selector "button", text: "Copied!"
    end
    assert_selector "[data-clipboard-target='status']", text: /copied/i, visible: :all
  end

  test "the copy affordance is absent until a share link exists" do
    visit collection_path(collections(:instagram)) # no share minted

    assert_no_selector ".share-link-row"
    assert_selector "button", text: "Create share link"
  end
end
