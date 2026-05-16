require "test_helper"

class ProductNameInterpreterTest < ActiveSupport::TestCase
  test "keeps tuna varieties separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Chunk Light Tuna", interpreter.interpret("TUNA CHUNK LT CQ 66Z").canonical_name
    assert_equal "Tongol Tuna", interpreter.interpret("TUNA TONGOL CQ 66Z").canonical_name
  end

  test "keeps unknown tuna shorthand as a broad reviewable family" do
    result = Purchasing::ProductNameInterpreter.new.interpret("TUNA CHUNK LT CQ 66Z")

    assert_equal "Chunk Light Tuna", result.canonical_name
    assert result.auto_review?
    assert result.family_group?
    assert_operator result.confidence_score, :>=, 0.9
  end

  test "keeps butter formats and alternatives separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Butter Quarters", interpreter.interpret("BTR SWT QRTS ST 1LB").canonical_name
    assert_equal "Whipped Butter Cups", interpreter.interpret("BTR WHPCUP SLTD DB").canonical_name
    assert_equal "Whirl Liquid Butter Alternative", interpreter.interpret("OIL WHIRL LIQ BTR GAL").canonical_name
    assert_equal "Butter Alternative Oil", interpreter.interpret("OIL BTR ALT CQ GAL").canonical_name
  end

  test "keeps bacon smoke and slice specifications separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Applewood Bacon 14/18", interpreter.interpret("BACON APLW GMS 15# 14/18").canonical_name
    assert_equal "Applewood Bacon 18/22", interpreter.interpret("BACON GMS APLW 15# 18/22").canonical_name
    assert_equal "Hickory Bacon", interpreter.interpret("BACON GMS HICK 15# 18/22").canonical_name
  end

  test "keeps egg sizes separate while allowing package amounts within a size" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Large Eggs", interpreter.interpret("EGGS LRG LS GRD A 15DZ").canonical_name
    assert_equal "Large Eggs", interpreter.interpret("EGGS LRG LS GRD A 7.5DZ").canonical_name
    assert_equal "Extra Large Eggs", interpreter.interpret("EGGS XLG LS GRD A 15DZ").canonical_name
    assert_equal "Medium Eggs", interpreter.interpret("EGGS MED LS GRD A 15DZ").canonical_name
  end

  test "keeps American cheese color variants separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "American Cheese Yellow", interpreter.interpret("CHS AM YL 120SL JF 5LB").canonical_name
    assert_equal "American Cheese White", interpreter.interpret("CHS AMER WHT 120JF 5LB").canonical_name
  end

  test "keeps sausage patties and links separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Sausage Patties 2 oz", interpreter.interpret("FZ SAU PATY CK 2OZ 10LB").canonical_name
    assert_equal "Sausage Links", interpreter.interpret("FZ SAUS CK LK SKLS .8OZ").canonical_name
  end

  test "keeps uncertain fallback names reviewable" do
    result = Purchasing::ProductNameInterpreter.new.interpret("GL QUAL HS MIX 16Z 2DZ/CS")

    assert_equal "Gl Hs Mix", result.canonical_name
    assert_not result.auto_review?
    assert_not result.family_group?
  end

  test "writes conservative inference notes without inventing units" do
    notes = Purchasing::ProductNameInterpreter.new.notes_for(
      canonical_name: "Tuna",
      raw_names: [ "TUNA CHUNK LT CQ 66Z", "TUNA TONGOL CQ 66Z" ],
      confidence_score: 0.95,
      basis: "raw name contains TUNA"
    )

    assert_includes notes, "Codex inference"
    assert_includes notes, "TUNA CHUNK LT CQ 66Z"
    assert_includes notes, "TUNA TONGOL CQ 66Z"
    assert_includes notes, "does not invent missing units"
  end
end
