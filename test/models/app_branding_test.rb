require "test_helper"
require "tempfile"

class AppBrandingTest < ActiveSupport::TestCase
  test "uses private branding values when configured" do
    Tempfile.create([ "branding", ".yml" ]) do |file|
      file.write({ "app_name" => "Kitchen Count", "short_name" => "Count" }.to_yaml)
      file.close

      with_config_path(Pathname(file.path)) do
        branding = AppBranding.current

        assert_equal "Kitchen Count", branding.app_name
        assert_equal "Count", branding.short_name
        assert_equal "Restaurant inventory, purchasing, order-guide, and price intelligence.", branding.description
      end
    end
  end

  test "ignores invalid private branding config" do
    Tempfile.create([ "branding", ".yml" ]) do |file|
      file.write("app_name: [")
      file.close

      with_config_path(Pathname(file.path)) do
        branding = AppBranding.current

        assert_equal "Inventory OS", branding.app_name
      end
    end
  end

  private

  def with_config_path(path)
    original = AppBranding.method(:config_path)
    AppBranding.define_singleton_method(:config_path) { path }
    yield
  ensure
    AppBranding.define_singleton_method(:config_path, original)
  end
end
