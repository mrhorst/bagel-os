require "net/http"

module PhotoAssets
  # Produces a lightly edited copy of a photo (clear background clutter,
  # clean a dirty plate) via an image-editing model, attached as a separate
  # treated_photo. The original is never modified.
  class AiTreatment
    DEFAULT_MODEL = "gemini-2.5-flash-image".freeze
    TIMEOUT_SECONDS = 90

    BASE_INSTRUCTIONS = <<~PROMPT.freeze
      Edit this restaurant marketing photo. Remove background clutter and clean
      any dirty plate rims, smudges, or stains on surfaces. Keep the photo
      photorealistic: do not change, replace, or beautify the food itself, and
      keep the original lighting, colors, framing, and composition.
    PROMPT

    def self.configured?
      ENV["GEMINI_API_KEY"].present?
    end

    def initialize(api_key: ENV["GEMINI_API_KEY"], model: ENV.fetch("MARKETING_AI_TREATMENT_MODEL", DEFAULT_MODEL))
      @api_key = api_key
      @model = model
    end

    # Returns true when a treated photo was attached.
    def treat!(asset)
      bytes, mime = fetch_treated_image(asset)
      return false if bytes.nil?

      attach_treated!(asset, bytes, mime)
      true
    end

    def attach_treated!(asset, bytes, mime)
      extension = mime.to_s.split("/").last.presence || "png"
      asset.treated_photo.attach(
        io: StringIO.new(bytes),
        filename: "photo-#{asset.id}-treated.#{extension}",
        content_type: mime
      )
      asset.update!(treated_at: Time.current)
    end

    private

    attr_reader :api_key, :model

    def fetch_treated_image(asset)
      data, media_type = PhotoBytes.jpeg_payload(asset.photo)

      uri = URI.parse("https://generativelanguage.googleapis.com/v1/models/#{model}:generateContent")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["x-goog-api-key"] = api_key
      request.body = JSON.generate(
        contents: [ {
          parts: [
            { text: prompt_for(asset) },
            { inline_data: { mime_type: media_type, data: Base64.strict_encode64(data) } }
          ]
        } ]
      )

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 15, read_timeout: TIMEOUT_SECONDS) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("AI treatment failed for photo asset #{asset.id}: HTTP #{response.code}")
        return nil
      end

      extract_image(JSON.parse(response.body))
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
      Rails.logger.warn("AI treatment failed for photo asset #{asset.id}: #{error.class}: #{error.message}")
      nil
    end

    def prompt_for(asset)
      specific = asset.treatment_instructions.to_s.strip
      specific.present? ? "#{BASE_INSTRUCTIONS}\nSpecifically: #{specific}" : BASE_INSTRUCTIONS
    end

    def extract_image(payload)
      parts = payload.dig("candidates", 0, "content", "parts")
      part = Array(parts).find { |p| p["inlineData"] || p["inline_data"] }
      return nil if part.nil?

      inline = part["inlineData"] || part["inline_data"]
      data = inline["data"]
      return nil if data.blank?

      [ Base64.decode64(data), inline["mimeType"] || inline["mime_type"] || "image/png" ]
    end
  end
end
