require "test_helper"

class OrderGuidesImportCurrentTest < ActionDispatch::IntegrationTest
  setup do
    @current_dir = OrderGuidesController::CURRENT_GUIDE_DIR
    FileUtils.rm_rf(@current_dir)
  end

  teardown do
    FileUtils.rm_rf(@current_dir)
  end

  test "reports when no current guide PDFs exist" do
    post import_current_order_guides_path

    assert_redirected_to order_guides_path
    assert_equal "No PDF files found in #{@current_dir}.", flash[:alert]
  end

  test "reports guide import errors without crashing the request" do
    FileUtils.mkdir_p(@current_dir)
    File.write(@current_dir.join("supplier-list.pdf"), "not a real guide")

    post import_current_order_guides_path

    assert_redirected_to order_guides_path
    assert_match(/Could not infer guide type/, flash[:alert])
  end
end
