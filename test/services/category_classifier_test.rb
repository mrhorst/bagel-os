require "test_helper"

class CategoryClassifierTest < ActiveSupport::TestCase
  setup { @classifier = Purchasing::CategoryClassifier.new }

  test "classifies a description by its keyword rule" do
    eggs = ProductCategory.create!(name: "Eggs")

    assert_equal eggs, @classifier.category_for("LRG EGGS 15 DZ")
  end

  test "falls back to the unknown category when no rule matches" do
    result = @classifier.category_for("ZQX NONSENSE 99")

    assert_equal "Other / unknown", result.name
  end

  test "falls back to unknown when the matched category row does not exist yet" do
    # "MILK" matches the Dairy rule, but no Dairy category exists.
    result = @classifier.category_for("WHOLE MILK GAL")

    assert_equal "Other / unknown", result.name
  end
end
