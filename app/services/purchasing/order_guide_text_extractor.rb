require "open3"

module Purchasing
  class OrderGuideTextExtractor
    class ExtractionError < StandardError; end

    def extract(path)
      stdout, stderr, status = Open3.capture3("pdftotext", "-layout", path.to_s, "-")
      return stdout if status.success?

      raise ExtractionError, "Could not extract #{File.basename(path)} with pdftotext: #{stderr.presence || 'unknown error'}"
    rescue Errno::ENOENT
      raise ExtractionError, "pdftotext is required to import order guide PDFs."
    end
  end
end
