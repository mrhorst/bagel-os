require "test_helper"

class OrderGuideTextExtractorTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)

  test "returns extracted layout text when pdftotext succeeds" do
    with_capture3_result([ "Guide text", "", Status.new(true) ]) do
      assert_equal "Guide text", Purchasing::OrderGuideTextExtractor.new.extract("guide.pdf")
    end
  end

  test "raises a readable extraction error when pdftotext fails" do
    with_capture3_result([ "", "bad pdf", Status.new(false) ]) do
      error = assert_raises(Purchasing::OrderGuideTextExtractor::ExtractionError) do
        Purchasing::OrderGuideTextExtractor.new.extract("guide.pdf")
      end

      assert_equal "Could not extract guide.pdf with pdftotext: bad pdf", error.message
    end
  end

  test "raises a setup error when pdftotext is not installed" do
    with_capture3_result(->(*_args) { raise Errno::ENOENT }) do
      error = assert_raises(Purchasing::OrderGuideTextExtractor::ExtractionError) do
        Purchasing::OrderGuideTextExtractor.new.extract("guide.pdf")
      end

      assert_equal "pdftotext is required to import order guide PDFs.", error.message
    end
  end

  private

  def with_capture3_result(result)
    original = Open3.method(:capture3)
    Open3.define_singleton_method(:capture3) do |*args|
      result.respond_to?(:call) ? result.call(*args) : result
    end
    yield
  ensure
    Open3.define_singleton_method(:capture3, original)
  end
end
