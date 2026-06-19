require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without the marketing module is turned away" do
    sign_in_as(users(:two))
    get collections_path
    assert_redirected_to root_path
  end

  test "marketing user can list, view, and reach the forms" do
    employee = users(:two)
    employee.grant_module("marketing")
    sign_in_as(employee)

    get collections_path
    assert_response :success
    get collection_path(collections(:summer))
    assert_response :success
    get new_collection_path
    assert_response :success
    get edit_collection_path(collections(:summer))
    assert_response :success
  end

  test "creates a collection and derives the slug from the name" do
    sign_in_as(users(:one))

    assert_difference "Collection.count", 1 do
      post collections_path, params: { collection: { name: "Fall Specials", description: "Autumn menu." } }
    end
    created = Collection.order(:created_at).last
    assert_redirected_to collection_path(created)
    assert_equal "fall-specials", created.slug
    assert_equal users(:one), created.created_by
  end

  test "invalid collection re-renders the form" do
    sign_in_as(users(:one))

    assert_no_difference "Collection.count" do
      post collections_path, params: { collection: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "updates a collection" do
    sign_in_as(users(:one))

    patch collection_path(collections(:summer)), params: { collection: { description: "Updated." } }
    assert_redirected_to collection_path(collections(:summer))
    assert_equal "Updated.", collections(:summer).reload.description
  end

  test "deleting a collection keeps the photos in the library" do
    sign_in_as(users(:one))
    collection = collections(:instagram)
    collection.collection_memberships.create!(photo_asset: create_asset)

    assert_difference -> { Collection.count } => -1, -> { PhotoAsset.count } => 0 do
      delete collection_path(collection)
    end
    assert_redirected_to collections_path
  end

  private

  def create_asset
    PhotoAsset.new.tap do |asset|
      asset.photo.attach(
        io: file_fixture("photo_asset_sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      asset.save!
    end
  end
end
