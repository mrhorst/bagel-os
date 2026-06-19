require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "primary is idempotent and uses the generic placeholder name" do
    first = Supplier.primary
    second = Supplier.primary

    assert_equal first.id, second.id
    assert_equal "Primary Supplier", first.name
  end

  test "name is required and unique" do
    Supplier.create!(name: "Secondary Supplier")
    duplicate = Supplier.new(name: "Secondary Supplier")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_not Supplier.new.valid?
  end
end
