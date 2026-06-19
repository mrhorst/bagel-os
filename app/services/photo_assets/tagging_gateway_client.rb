module PhotoAssets
  # Posts a photo *tagging* request to the agent gateway. All transport lives in
  # AgentGatewayClient; this only names the task.
  class TaggingGatewayClient < AgentGatewayClient
    private

    def default_model
      "hermes-photo-tagging"
    end

    def prompt_prefix
      "Tag this photo per the payload:"
    end

    def log_label
      "Photo tagging gateway"
    end
  end
end
