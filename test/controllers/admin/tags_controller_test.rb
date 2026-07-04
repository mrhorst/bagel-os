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

    test "a whitespace-only name re-renders naming the name, never leaking the derived Slug field" do
      sign_in_as(users(:one))

      # A whitespace-only name slips past the field's HTML5 `required` and reaches
      # the server. The banner must name the real mistake (the missing name), not
      # scold the Slug field the admin was told to leave blank.
      assert_no_difference "Tag.count" do
        post admin_tags_path, params: { tag: { name: "   " } }
      end
      assert_response :unprocessable_entity
      assert_select "div.flash-alert li", text: /Name can't be blank/
      assert_select "div.flash-alert", text: /Slug/, count: 0
    end

    test "a name with no usable characters re-renders in name terms, not as a Slug error" do
      sign_in_as(users(:one))

      # An emoji-only name (common for a non-English restaurant) is present but
      # derives a blank slug. The admin must be pointed at their name, not handed
      # a "Slug can't be blank" for a field they never typed in.
      assert_no_difference "Tag.count" do
        post admin_tags_path, params: { tag: { name: "🌮" } }
      end
      assert_response :unprocessable_entity
      assert_select "div.flash-alert li", text: /can't be turned into a tag/
      assert_select "div.flash-alert", text: /Slug/, count: 0
    end

    test "a duplicate name with a blank slug re-renders with a name-anchored error, not a leaked Slug field" do
      sign_in_as(users(:one))

      # The admin follows the form's "Leave blank to derive it from the name"
      # hint and re-types an existing name. The error must point at what they
      # actually typed, never "Slug has already been taken" for a field they left
      # empty on purpose.
      assert_no_difference "Tag.count" do
        post admin_tags_path, params: { tag: { name: "Food" } }
      end
      assert_response :unprocessable_entity
      assert_select "div.flash-alert", text: /A tag named "Food" already exists/
      assert_select "div.flash-alert", text: /Slug has already been taken/, count: 0
    end

    test "admin updates a tag's rule" do
      sign_in_as(users(:one))

      patch admin_tag_path(tags(:food)), params: { tag: { instruction: "Anything edible or drinkable." } }
      assert_redirected_to admin_tags_path
      assert_equal "Anything edible or drinkable.", tags(:food).reload.instruction
    end

    test "an invalid update re-renders the edit form instead of crashing on the delete danger zone" do
      sign_in_as(users(:one))

      # The edit view's delete danger zone reads @photo_count, which the update
      # action must set before re-rendering :edit on a failed save. Otherwise a
      # blank name (or any validation error) renders with @photo_count = nil and
      # 500s on nil.zero? — turning an ordinary mistake into a hard crash that
      # also discards the admin's edits. This exercises both a tag with photos
      # and one without so both danger-zone branches render.
      patch admin_tag_path(tags(:food)), params: { tag: { name: "" } }
      assert_response :unprocessable_entity
      assert_select "div.flash-alert li", text: /Name can't be blank/
      assert_equal "Food", tags(:food).reload.name

      patch admin_tag_path(tags(:product)), params: { tag: { name: "" } }
      assert_response :unprocessable_entity
      assert_select ".panel-danger-zone p", text: /isn't on any photos yet/
    end

    test "the delete danger zone names how many photos carry the tag" do
      sign_in_as(users(:one))
      2.times do |i|
        asset = PhotoAsset.new.tap do |a|
          a.photo.attach(io: file_fixture("photo_asset_sample.png").open, filename: "s#{i}.png", content_type: "image/png")
          a.save!
        end
        asset.taggings.create!(tag: tags(:food), source: "manual", confirmed_at: Time.current)
      end

      get edit_admin_tag_path(tags(:food))
      assert_response :success
      # The warning copy and the confirm dialog both name the real blast radius.
      assert_select ".panel-danger-zone p", text: /from the 2 photos it's on/
      assert_select "[data-turbo-confirm*=?]", "It's on 2 photos"
    end

    test "the delete confirm for an unused tag stays plain with no photo count" do
      sign_in_as(users(:one))
      assert_equal 0, tags(:product).taggings.count

      get edit_admin_tag_path(tags(:product))
      assert_response :success
      assert_select ".panel-danger-zone p", text: /isn't on any photos yet/
      assert_select "[data-turbo-confirm=?]", "Delete Product?"
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
