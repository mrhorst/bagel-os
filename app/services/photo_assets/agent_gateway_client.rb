require "net/http"
require "openssl"

module PhotoAssets
  # Shared transport for the marketing photo agent gateway (e.g. Hermes).
  # Endpoints ending in /v1/chat/completions get an OpenAI-style vision payload;
  # anything else gets the raw payload with HMAC signing. Subclasses supply the
  # task's prompt prefix, default model, and log label — everything else (auth,
  # timeouts, JSON extraction, error handling) is identical across tasks.
  class AgentGatewayClient
    DEFAULT_TIMEOUT_SECONDS = 30

    def initialize(
      endpoint: ENV["MARKETING_PHOTO_AGENT_GATEWAY_URL"],
      token: ENV["MARKETING_PHOTO_AGENT_GATEWAY_TOKEN"],
      model: ENV.fetch("MARKETING_PHOTO_AGENT_GATEWAY_MODEL", default_model),
      timeout_seconds: ENV.fetch("MARKETING_PHOTO_AGENT_GATEWAY_TIMEOUT", DEFAULT_TIMEOUT_SECONDS).to_i
    )
      @endpoint = endpoint.presence
      @token = token.presence
      @model = model
      @timeout_seconds = timeout_seconds.positive? ? timeout_seconds : DEFAULT_TIMEOUT_SECONDS
    end

    def configured?
      endpoint.present?
    end

    def call(payload, image_base64:, image_mime:)
      return nil unless configured?

      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      if chat_completions_endpoint?(uri)
        request["Authorization"] = "Bearer #{token}" if token.present?
        request.body = JSON.generate(chat_completions_payload(payload, image_base64:, image_mime:))
      else
        request.body = JSON.generate(payload.merge("photo" => { "mime_type" => image_mime, "data_base64" => image_base64 }))
        sign_request!(request)
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: timeout_seconds, read_timeout: timeout_seconds) do |http|
        http.request(request)
      end
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      return parse_chat_completions_response(parsed_response) if chat_completions_endpoint?(uri)

      parsed_response
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, URI::InvalidURIError, OpenSSL::SSL::SSLError => error
      Rails.logger.warn("#{log_label} failed: #{error.class}: #{error.message}")
      nil
    end

    private

    # Subclasses override these three to specialise the task.
    def default_model
      raise NotImplementedError
    end

    def prompt_prefix
      raise NotImplementedError
    end

    def log_label
      "Photo agent gateway"
    end

    attr_reader :endpoint, :token, :model, :timeout_seconds

    def chat_completions_endpoint?(uri)
      uri.path.end_with?("/v1/chat/completions")
    end

    def chat_completions_payload(payload, image_base64:, image_mime:)
      {
        "model" => model,
        "stream" => false,
        "messages" => [
          {
            "role" => "user",
            "content" => [
              { "type" => "text", "text" => "Return ONLY valid JSON. #{prompt_prefix}\n\n#{JSON.pretty_generate(payload)}" },
              { "type" => "image_url", "image_url" => { "url" => "data:#{image_mime};base64,#{image_base64}" } }
            ]
          }
        ]
      }
    end

    def parse_chat_completions_response(response)
      content = response.dig("choices", 0, "message", "content")
      return nil if content.blank?

      JSON.parse(extract_json(content))
    end

    # Local models often wrap JSON in a code fence or prose despite
    # instructions — pull out the first JSON object.
    def extract_json(content)
      content[/\{.*\}/m] || content
    end

    def sign_request!(request)
      return if token.blank?

      signature = OpenSSL::HMAC.hexdigest("SHA256", token, request.body)
      request["X-Hub-Signature-256"] = "sha256=#{signature}"
      request["X-Webhook-Signature"] = signature
    end
  end
end
