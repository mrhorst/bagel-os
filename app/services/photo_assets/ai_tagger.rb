module PhotoAssets
  # AI-assisted tagging of a photo asset via the configured agent gateway
  # (e.g. Hermes). The gateway is shown the admin-managed tag vocabulary and
  # each tag's rule, and picks the slugs that match what's in the photo. The
  # picks land as *unconfirmed* taggings — a human reviews and confirms them
  # from the photo's page. Hermes never has the final say.
  class AiTagger
    def self.configured?
      TaggingGatewayClient.new.configured?
    end

    def initialize(gateway_client: TaggingGatewayClient.new)
      @gateway_client = gateway_client
    end

    # Fetches suggested slugs and applies them. Returns the array of slugs
    # applied (possibly empty), or nil when the gateway is unavailable.
    def tag!(asset)
      vocabulary = Tag.active.ordered.to_a
      slugs = fetch_slugs(asset, vocabulary)
      return nil if slugs.nil?

      apply!(asset, slugs, vocabulary)
    end

    # Applying is separate from fetching so the write path is testable without
    # network access. Adds an unconfirmed "ai" tagging for each matching slug,
    # leaving any existing tagging untouched, and stamps the tagging pass.
    def apply!(asset, slugs, vocabulary = Tag.active.ordered.to_a)
      by_slug = vocabulary.index_by(&:slug)
      applied = []

      Array(slugs).each do |slug|
        tag = by_slug[slug]
        next if tag.nil?

        tagging = asset.taggings.find_or_initialize_by(tag: tag)
        if tagging.new_record?
          tagging.source = "ai"
          tagging.confirmed_at = nil
          tagging.save!
        end
        applied << tag.slug
      end

      asset.update_column(:ai_tagged_at, Time.current)
      asset.refresh_status!
      applied
    end

    private

    attr_reader :gateway_client

    def fetch_slugs(asset, vocabulary)
      return nil unless gateway_client.configured?
      return [] if vocabulary.empty?

      data, media_type = PhotoBytes.jpeg_payload(asset.photo)
      response = gateway_client.call(
        gateway_payload(asset, vocabulary),
        image_base64: Base64.strict_encode64(data),
        image_mime: media_type
      )
      normalize_slugs(response, vocabulary)
    end

    def gateway_payload(asset, vocabulary)
      {
        "gateway" => "photo_tagging",
        "version" => 1,
        "photo_asset_id" => asset.id,
        "instructions" => INSTRUCTIONS,
        "allowed_tags" => vocabulary.map { |tag| { "slug" => tag.slug, "name" => tag.name, "rule" => tag.instruction.to_s } }
      }
    end

    INSTRUCTIONS = [
      "You tag photos for a restaurant's marketing asset library so staff can find them later.",
      "Choose only from allowed_tags and return each tag's slug exactly as given.",
      "Apply every tag whose rule matches what you can clearly see; skip the rest. Do not invent tags or slugs.",
      "Return JSON with exactly one key: tags — an array of matching slugs (it may be empty)."
    ].freeze

    def normalize_slugs(response, vocabulary)
      return nil unless response.is_a?(Hash)

      allowed = vocabulary.map(&:slug)
      raw = response["tags"]
      return [] unless raw.is_a?(Array)

      raw.map { |slug| slug.to_s.strip.downcase }.select { |slug| allowed.include?(slug) }.uniq
    end
  end
end
