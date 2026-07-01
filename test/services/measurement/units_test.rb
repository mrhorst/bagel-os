require "test_helper"

module Measurement
  class UnitsTest < ActiveSupport::TestCase
    test "recognises canonical units and common spellings" do
      assert_equal "lb", Units.canonical("lb")
      assert_equal "lb", Units.canonical("Lbs")
      assert_equal "lb", Units.canonical(" pound ")
      assert_equal "oz", Units.canonical("ounces")
      assert_equal "g", Units.canonical("grams")
      assert_equal "cup", Units.canonical("Cups")
      assert_equal "fl_oz", Units.canonical("fl oz")
      assert_equal "tbsp", Units.canonical("Tbsp.")
      assert_equal "each", Units.canonical("ea")
      assert_equal "dozen", Units.canonical("doz")
    end

    test "returns nil for unknown or blank units" do
      assert_nil Units.canonical("scoop")
      assert_nil Units.canonical("pinch")
      assert_nil Units.canonical("")
      assert_nil Units.canonical(nil)
    end

    test "reports the dimension of a unit" do
      assert_equal Units::WEIGHT, Units.dimension("lb")
      assert_equal Units::VOLUME, Units.dimension("cup")
      assert_equal Units::COUNT, Units.dimension("each")
      assert_nil Units.dimension("scoop")
    end

    test "same_dimension? only matches within a dimension" do
      assert Units.same_dimension?("lb", "oz")
      assert Units.same_dimension?("cup", "tbsp")
      assert_not Units.same_dimension?("cup", "lb")
      assert_not Units.same_dimension?("lb", "scoop")
    end

    test "converts within the weight dimension" do
      assert_equal BigDecimal("16"), Units.convert(1, from: "lb", to: "oz")
      assert_in_delta 453.59237, Units.convert(1, from: "lb", to: "g"), 0.0001
      assert_equal BigDecimal("1"), Units.convert(1000, from: "g", to: "kg")
    end

    test "converts within the count dimension" do
      assert_equal BigDecimal("24"), Units.convert(2, from: "dozen", to: "each")
      assert_equal BigDecimal("1"), Units.convert(12, from: "each", to: "dozen")
    end

    test "never converts across dimensions" do
      assert_nil Units.convert(1, from: "cup", to: "lb")
      assert_nil Units.convert(1, from: "each", to: "g")
    end

    test "returns nil converting unknown units or blank quantities" do
      assert_nil Units.convert(1, from: "scoop", to: "lb")
      assert_nil Units.convert(1, from: "lb", to: "scoop")
      assert_nil Units.convert(nil, from: "lb", to: "oz")
    end

    test "expresses a quantity in its dimension base unit" do
      assert_in_delta 453.59237, Units.to_base(1, "lb"), 0.0001
      assert_equal BigDecimal("500"), Units.to_base(0.5, "l")
      assert_equal BigDecimal("12"), Units.to_base(1, "dozen")
      assert_nil Units.to_base(1, "scoop")
    end
  end
end
