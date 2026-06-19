module PhotoAssets
  # Posts a photo *description* request (caption, hashtags, alt text) to the
  # agent gateway. All transport lives in AgentGatewayClient; this only names
  # the task.
  class DescriptionGatewayClient < AgentGatewayClient
    private

    def default_model
      "hermes-photo-caption"
    end

    def prompt_prefix
      "Write marketing copy for this photo per the payload:"
    end

    def log_label
      "Photo description gateway"
    end
  end
end
