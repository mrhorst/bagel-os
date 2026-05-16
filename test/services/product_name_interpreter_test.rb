require "test_helper"

class ProductNameInterpreterTest < ActiveSupport::TestCase
  test "normalizes tuna receipt shorthand into a simple product family" do
    result = Purchasing::ProductNameInterpreter.new.interpret("TUNA CHUNK LT CQ 66Z")

    assert_equal "Tuna", result.canonical_name
    assert result.auto_review?
    assert result.family_group?
    assert_operator result.confidence_score, :>=, 0.9
  end

  test "keeps American cheese color variants separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "American Cheese Yellow", interpreter.interpret("CHS AM YL 120SL JF 5LB").canonical_name
    assert_equal "American Cheese White", interpreter.interpret("CHS AMER WHT 120JF 5LB").canonical_name
  end

  test "keeps sausage patties and links separate" do
    interpreter = Purchasing::ProductNameInterpreter.new

    assert_equal "Sausage Patties", interpreter.interpret("FZ SAU PATY CK 2OZ 10LB").canonical_name
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
