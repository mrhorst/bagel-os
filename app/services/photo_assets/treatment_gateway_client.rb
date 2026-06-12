require "net/http"
require "openssl"

module PhotoAssets
  # Posts a photo treatment request to the agent gateway (e.g. Hermes running
  # an image-capable model) and returns the edited image bytes. Mirrors
  # ReviewGatewayClient; falls back to the review gateway's URL and token so
  # one gateway config serves both.
  #
  # Chat-completions endpoints get the request with modalities ["image",
  # "text"] and the photo as a data URL; the edited image is accepted from
  # the common response shapes (message.images[], image_url content parts,
  # or a data URL in the content string).
  class TreatmentGatewayClient
    DEFAULT_TIMEOUT_SECONDS = 120
    DEFAULT_MODEL = "hermes-photo-treatment".freeze
    DATA_URL_PATTERN = %r{data:(image/[a-z0-9.+-]+);base64,([A-Za-z0-9+/=\s]+)}i

    def initialize(
      endpoint: ENV["MARKETING_PHOTO_TREATMENT_GATEWAY_URL"].presence || ENV["MARKETING_PHOTO_AGENT_GATEWAY_URL"],
      token: ENV["MARKETING_PHOTO_TREATMENT_GATEWAY_TOKEN"].presence || ENV["MARKETING_PHOTO_AGENT_GATEWAY_TOKEN"],
      model: ENV.fetch("MARKETING_PHOTO_TREATMENT_GATEWAY_MODEL", DEFAULT_MODEL),
      timeout_seconds: ENV.fetch("MARKETING_PHOTO_TREATMENT_GATEWAY_TIMEOUT", DEFAULT_TIMEOUT_SECONDS).to_i
    )
      @endpoint = endpoint.presence
      @token = token.presence
      @model = model
      @timeout_seconds = timeout_seconds.positive? ? timeout_seconds : DEFAULT_TIMEOUT_SECONDS
    end

    def configured?
      endpoint.present?
    end

    # Returns [bytes, mime] for the edited image, or nil.
    def call(instructions, image_base64:, image_mime:)
      return nil unless configured?

      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      if chat_completions_endpoint?(uri)
        request["Authorization"] = "Bearer #{token}" if token.present?
        request.body = JSON.generate(chat_completions_payload(instructions, image_base64:, image_mime:))
      else
        request.body = JSON.generate(
          "gateway" => "photo_treatment",
          "version" => 1,
          "instructions" => instructions,
          "photo" => { "mime_type" => image_mime, "data_base64" => image_base64 }
        )
        sign_request!(request)
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: timeout_seconds) do |http|
        http.request(request)
      end
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      return parse_chat_completions_response(parsed_response) if chat_completions_endpoint?(uri)

      parse_generic_response(parsed_response)
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, URI::InvalidURIError, OpenSSL::SSL::SSLError => error
      Rails.logger.warn("Photo treatment gateway failed: #{error.class}: #{error.message}")
      nil
    end

    private

    attr_reader :endpoint, :token, :model, :timeout_seconds

    def chat_completions_endpoint?(uri)
      uri.path.end_with?("/v1/chat/completions")
    end

    def chat_completions_payload(instructions, image_base64:, image_mime:)
      {
        "model" => model,
        "stream" => false,
        "modalities" => [ "image", "text" ],
        "messages" => [
          {
            "role" => "user",
            "content" => [
              { "type" => "text", "text" => instructions },
              { "type" => "image_url", "image_url" => { "url" => "data:#{image_mime};base64,#{image_base64}" } }
            ]
          }
        ]
      }
    end

    def parse_chat_completions_response(response)
      message = response.dig("choices", 0, "message")
      return nil unless message.is_a?(Hash)

      decode_data_url(image_data_url(message))
    end

    def image_data_url(message)
      urls = Array(message["images"]).filter_map do |image|
        image.is_a?(Hash) ? image.dig("image_url", "url") || image["url"] : image
      end

      content = message["content"]
      if content.is_a?(Array)
        urls += content.filter_map { |part| part.dig("image_url", "url") if part.is_a?(Hash) }
      elsif content.is_a?(String)
        urls << content[DATA_URL_PATTERN]
      end

      urls.compact.find { |url| url.to_s.start_with?("data:image") }
    end

    def decode_data_url(url)
      match = url.to_s.match(DATA_URL_PATTERN)
      return nil if match.nil?

      [ Base64.decode64(match[2]), match[1].downcase ]
    end

    def parse_generic_response(response)
      photo = response["photo"]
      return nil unless photo.is_a?(Hash) && photo["data_base64"].present?

      [ Base64.decode64(photo["data_base64"]), photo["mime_type"].presence || "image/png" ]
    end

    def sign_request!(request)
      return if token.blank?

      signature = OpenSSL::HMAC.hexdigest("SHA256", token, request.body)
      request["X-Hub-Signature-256"] = "sha256=#{signature}"
      request["X-Webhook-Signature"] = signature
    end
  end
end
