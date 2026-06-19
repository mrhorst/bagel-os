require "test_helper"

module Admin
  class TagsControllerTest < ActionDispatch::IntegrationTest
    self.skip_default_sign_in = true

    test "non-admins are turned away" do
      employee = users(:two)
      employee.grant_module("marketing")
      sign_in_as(employee)

      get admin_tags_path
      assert_redirected_to root_path
    end

    test "admin can list tags" do
      sign_in_as(users(:one))
      get admin_tags_path
      assert_response :success
    end

    test "the new and edit forms render" do
      sign_in_as(users(:one))
      get new_admin_tag_path
      assert_response :success
      get edit_admin_tag_path(tags(:food))
      assert_response :success
    end

    test "admin creates a tag and the slug is derived from the name" do
      sign_in_as(users(:one))

      assert_difference "Tag.count", 1 do
        post admin_tags_path, params: { tag: { name: "Storefront", instruction: "Exterior and signage." } }
      end
      assert_redirected_to admin_tags_path
      assert_equal "storefront", Tag.order(:created_at).last.slug
    end

    test "invalid tag re-renders the form" do
      sign_in_as(users(:one))

      assert_no_difference "Tag.count" do
        post admin_tags_path, params: { tag: { name: "" } }
      end
      assert_response :unprocessable_entity
    end

    test "admin updates a tag's rule" do
      sign_in_as(users(:one))

      patch admin_tag_path(tags(:food)), params: { tag: { instruction: "Anything edible or drinkable." } }
      assert_redirected_to admin_tags_path
      assert_equal "Anything edible or drinkable.", tags(:food).reload.instruction
    end

    test "deleting a tag removes it from photos and refreshes their status" do
      sign_in_as(users(:one))
      asset = PhotoAsset.new.tap do |a|
        a.photo.attach(io: file_fixture("photo_asset_sample.png").open, filename: "s.png", content_type: "image/png")
        a.save!
      end
      asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)
      assert_equal "tagged", asset.reload.status

      assert_difference "Tag.count", -1 do
        delete admin_tag_path(tags(:food))
      end
      assert_equal "pending", asset.reload.status
    end
  end
end
