module PhotoAssets
  # AI-assisted marketing copy for a photo via the agent gateway: a suggested
  # caption, hashtags, and alt text. Output lands in *suggestion* fields, so
  # generating never clobbers a human edit — staff apply the caption when they
  # want it.
  class AiDescriber
    def self.configured?
      DescriptionGatewayClient.new.configured?
    end

    def initialize(gateway_client: DescriptionGatewayClient.new)
      @gateway_client = gateway_client
    end

    # Fetches copy and stores it. Returns the asset, or nil when the gateway is
    # unavailable or returns nothing usable.
    def describe!(asset)
      copy = fetch_copy(asset)
      return nil if copy.nil?

      apply!(asset, copy)
    end

    # Separate from fetching so the write path is testable without network.
    # Keeps any human-entered alt text.
    def apply!(asset, copy)
      asset.update!(
        suggested_caption: copy[:caption].presence,
        hashtags: copy[:hashtags].presence,
        alt_text: asset.alt_text.presence || copy[:alt_text].presence,
        described_at: Time.current
      )
      asset
    end

    private

    attr_reader :gateway_client

    def fetch_copy(asset)
      return nil unless gateway_client.configured?

      data, media_type = PhotoBytes.jpeg_payload(asset.photo)
      response = gateway_client.call(
        gateway_payload(asset),
        image_base64: Base64.strict_encode64(data),
        image_mime: media_type
      )
      normalize(response)
    end

    def gateway_payload(asset)
      {
        "gateway" => "photo_description",
        "version" => 1,
        "photo_asset_id" => asset.id,
        "instructions" => INSTRUCTIONS
      }
    end

    INSTRUCTIONS = [
      "You write marketing copy for a restaurant's photo so staff can post it.",
      "Write a short, appetizing caption (one or two sentences, no hashtags inside it).",
      "Suggest 3-8 relevant hashtags as one space-separated string, each starting with #.",
      "Write concise, literal alt text describing what's in the photo for accessibility.",
      "Return JSON with exactly these keys: caption (string), hashtags (string), alt_text (string)."
    ].freeze

    def normalize(response)
      return nil unless response.is_a?(Hash)

      caption = response["caption"].to_s.strip
      hashtags = normalize_hashtags(response["hashtags"])
      alt_text = response["alt_text"].to_s.strip
      return nil if caption.blank? && hashtags.blank? && alt_text.blank?

      { caption: caption, hashtags: hashtags, alt_text: alt_text }
    end

    # Accept either a string or an array; emit a normalized "#a #b" string.
    def normalize_hashtags(raw)
      tokens =
        case raw
        when Array  then raw
        when String then raw.split
        else []
        end
      tokens.map { |token| token.to_s.strip }.reject(&:blank?)
        .map { |token| token.start_with?("#") ? token : "##{token}" }.join(" ")
    end
  end
end
