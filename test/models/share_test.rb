require "test_helper"

class ShareTest < ActiveSupport::TestCase
  test "generates a token on create" do
    share = collections(:summer).shares.create!
    assert share.token.present?
    assert_operator share.token.length, :>=, 20
  end

  test "is usable when neither revoked nor expired" do
    share = collections(:summer).shares.create!
    assert share.usable?
  end

  test "is not usable once revoked" do
    share = collections(:summer).shares.create!
    share.revoke!
    assert share.revoked?
    assert_not share.usable?
  end

  test "is not usable once expired" do
    share = collections(:summer).shares.create!(expires_at: 1.hour.ago)
    assert share.expired?
    assert_not share.usable?
  end

  test "active scope excludes revoked links" do
    live = collections(:summer).shares.create!
    dead = collections(:summer).shares.create!
    dead.revoke!

    assert_includes Collection.find(collections(:summer).id).shares.active, live
    assert_not_includes collections(:summer).shares.active, dead
  end

  test "destroying a collection removes its shares" do
    collection = Collection.create!(name: "Throwaway")
    collection.shares.create!

    assert_difference "Share.count", -1 do
      collection.destroy
    end
  end
end
