require "net/http"
require "openssl"

module Tasks
  class BriefingGatewayClient
    DEFAULT_TIMEOUT_SECONDS = 8

    def initialize(
      endpoint: ENV["TASK_BRIEFING_AGENT_GATEWAY_URL"],
      token: ENV["TASK_BRIEFING_AGENT_GATEWAY_TOKEN"],
      timeout_seconds: ENV.fetch("TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT", DEFAULT_TIMEOUT_SECONDS).to_i
    )
      @endpoint = endpoint.presence
      @token = token.presence
      @timeout_seconds = timeout_seconds.positive? ? timeout_seconds : DEFAULT_TIMEOUT_SECONDS
    end

    def configured?
      endpoint.present?
    end

    def config_digest
      Digest::SHA256.hexdigest([ endpoint, token.present?, timeout_seconds ].join("|"))
    end

    def call(payload)
      return nil unless configured?

      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      if chat_completions_endpoint?(uri)
        request["Authorization"] = "Bearer #{token}" if token.present?
        request.body = JSON.generate(chat_completions_payload(payload))
      else
        request.body = JSON.generate(payload)
        sign_request!(request)
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: timeout_seconds, read_timeout: timeout_seconds) do |http|
        http.request(request)
      end
      return nil unless response.is_a?(Net::HTTPSuccess)

      parsed_response = JSON.parse(response.body)
      return parse_chat_completions_response(parsed_response) if chat_completions_endpoint?(uri)

      parsed_response
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, URI::InvalidURIError => error
      Rails.logger.warn("Task briefing gateway failed: #{error.class}: #{error.message}")
      nil
    end

    private

    attr_reader :endpoint, :token, :timeout_seconds

    def chat_completions_endpoint?(uri)
      uri.path.end_with?("/v1/chat/completions")
    end

    def chat_completions_payload(payload)
      {
        "model" => "hermes-task-briefing",
        "stream" => false,
        "messages" => [
          {
            "role" => "user",
            "content" => "Return ONLY valid JSON. Generate a task briefing from this payload:\n\n#{JSON.pretty_generate(payload)}"
          }
        ]
      }
    end

    def parse_chat_completions_response(response)
      content = response.dig("choices", 0, "message", "content")
      return nil if content.blank?

      JSON.parse(content)
    end

    def sign_request!(request)
      return if token.blank?

      signature = OpenSSL::HMAC.hexdigest("SHA256", token, request.body)
      request["X-Hub-Signature-256"] = "sha256=#{signature}"
      request["X-Webhook-Signature"] = signature
    end
  end
end
