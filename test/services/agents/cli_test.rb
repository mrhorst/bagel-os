require "test_helper"

module Agents
  class CliTest < ActiveSupport::TestCase
    # Run the CLI with captured streams and return [exit_status, parsed_stdout,
    # raw_stderr]. parsed_stdout is nil when stdout was not JSON (e.g. help text).
    def run_cli(*argv)
      out = StringIO.new
      err = StringIO.new
      status = Agents::Cli.run(argv, out: out, err: err)
      stdout = out.string
      parsed = begin
        JSON.parse(stdout)
      rescue JSON::ParserError
        nil
      end
      [ status, parsed, err.string, stdout ]
    end

    test "bare invocation prints help listing every registered command and exits 0" do
      status, _json, _err, stdout = run_cli
      assert_equal 0, status
      Agents::Cli::REGISTRY.each do |command_class|
        assert_includes stdout, command_class.command
      end
    end

    test "help <command> prints that command's usage" do
      status, _json, _err, stdout = run_cli("help", "price:product")
      assert_equal 0, status
      assert_includes stdout, "price:product"
      assert_includes stdout, "--id"
    end

    test "unknown command returns an error envelope on stderr and exits 1" do
      status, _json, err, stdout = run_cli("frobnicate")
      assert_equal 1, status
      assert_empty stdout
      payload = JSON.parse(err)
      assert_equal false, payload["ok"]
      assert_equal "unknown_command", payload.dig("error", "type")
    end

    test "a successful command wraps its data in the standard envelope" do
      supplier = Supplier.create!(name: "CLI Test Supplier")
      Product.create!(canonical_name: "Sesame Bagel", supplier: supplier)

      status, json, _err, _stdout = run_cli("products:search", "sesame")
      assert_equal 0, status
      assert_equal true, json["ok"]
      assert_equal "products:search", json["command"]
      assert json["generated_at"].present?
      names = json.dig("data", "products").map { |p| p["canonical_name"] }
      assert_includes names, "Sesame Bagel"
    end

    test "products:search matches a raw alias as well as the canonical name" do
      supplier = Supplier.create!(name: "Alias Supplier")
      product = Product.create!(canonical_name: "Cream Cheese", supplier: supplier)
      product.product_aliases.create!(raw_name: "PHILLY CRM CHS 30#")

      _status, json, = run_cli("products:search", "philly")
      ids = json.dig("data", "products").map { |p| p["id"] }
      assert_includes ids, product.id
    end

    test "products:search escapes LIKE wildcards so % is a literal" do
      supplier = Supplier.create!(name: "Wildcard Supplier")
      Product.create!(canonical_name: "Plain Bagel", supplier: supplier)

      _status, json, = run_cli("products:search", "%")
      assert_equal 0, json.dig("data", "count")
    end

    test "an empty search query is a usage error" do
      status, _json, err, _stdout = run_cli("products:search")
      assert_equal 1, status
      assert_equal "usage_error", JSON.parse(err).dig("error", "type")
    end

    test "price:product reports not_found for an unmatched name" do
      status, _json, err, _stdout = run_cli("price:product", "definitely-not-a-product")
      assert_equal 1, status
      assert_equal "not_found", JSON.parse(err).dig("error", "type")
    end

    test "--compact emits single-line JSON" do
      _status, _json, _err, stdout = run_cli("purchasing:dashboard", "--compact")
      assert_equal 1, stdout.strip.lines.count
    end

    test "a non-integer numeric option is a usage error" do
      status, _json, err, _stdout = run_cli("tasks:history", "--days", "soon")
      assert_equal 1, status
      assert_equal "usage_error", JSON.parse(err).dig("error", "type")
    end
  end
end
