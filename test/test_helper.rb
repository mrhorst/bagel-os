ENV["RAILS_ENV"] ||= "test"
if ENV["CRAP_COVERAGE_OUTPUT"].to_s != ""
  require "coverage"
  Coverage.start(lines: true)
end

require_relative "../config/environment"
require "rails/test_help"
require "json"

if ENV["CRAP_COVERAGE_OUTPUT"].to_s != ""
  Minitest.after_run do
    coverage = Coverage.result(stop: true, clear: true)
    app_coverage = coverage.transform_keys { |path| path.delete_prefix("#{Rails.root}/") }
      .select { |path, _data| path.start_with?("app/") }

    FileUtils.mkdir_p(File.dirname(ENV.fetch("CRAP_COVERAGE_OUTPUT")))
    File.write(ENV.fetch("CRAP_COVERAGE_OUTPUT"), JSON.pretty_generate(app_coverage))
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
