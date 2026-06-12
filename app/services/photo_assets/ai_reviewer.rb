module PhotoAssets
  # First-pass review of a photo asset by the configured agent gateway
  # (e.g. Hermes, same pattern as task briefings): judges whether the shot
  # is usable for marketing, what needs fixing, and whether a light AI
  # treatment (background cleanup, dirty plate) would make it usable.
  # Staff can always override the verdict from the photo's page.
  class AiReviewer
    VERDICT_STATUSES = %w[approved needs_work rejected].freeze

    INSTRUCTIONS = [
      "You review photos for a restaurant's marketing library (menus, social media, website).",
      "Judge the photo on: focus and lighting, composition, cleanliness (dirty plates, smudges, messy or distracting backgrounds), and whether the food looks appetizing and realistic.",
      "status must be one of: approved (usable as-is or after a light cleanup edit), needs_work (a reshoot would fix it; give concrete guidance on angle, light, staging), rejected (not usable for marketing).",
      "notes: 1-3 plain sentences for restaurant staff.",
      "treatment_recommended: true only when a light edit (clear background clutter, wipe a dirty plate rim or smudge) would clearly help; never to alter the food itself.",
      "treatment_instructions: short edit instructions when treatment is recommended, otherwise empty.",
      "Do not invent details you cannot see. Return JSON with exactly these keys: status, notes, treatment_recommended, treatment_instructions."
    ].freeze

    def self.configured?
      ReviewGatewayClient.new.configured?
    end

    def initialize(gateway_client: ReviewGatewayClient.new)
      @gateway_client = gateway_client
    end

    # Reviews and applies the verdict. Returns the normalized verdict hash,
    # or nil when the gateway is unavailable or returns something unusable
    # (asset stays unreviewed for a human).
    def review!(asset)
      verdict = fetch_verdict(asset)
      return nil if verdict.nil?

      apply!(asset, verdict)
      verdict
    end

    # Applying is separate from fetching so the write path is testable
    # without network access.
    def apply!(asset, verdict)
      status = verdict["status"]
      raise ArgumentError, "unknown status #{status.inspect}" unless PhotoAsset::STATUSES.include?(status)

      asset.update!(
        status: status,
        notes: verdict["notes"].to_s.strip.presence,
        reviewed_via: "ai",
        reviewed_by: nil,
        reviewed_at: Time.current,
        treatment_instructions: verdict["treatment_recommended"] ? verdict["treatment_instructions"].to_s.strip.presence : nil
      )
    end

    private

    attr_reader :gateway_client

    def fetch_verdict(asset)
      return nil unless gateway_client.configured?

      data, media_type = PhotoBytes.jpeg_payload(asset.photo)
      response = gateway_client.call(
        gateway_payload(asset),
        image_base64: Base64.strict_encode64(data),
        image_mime: media_type
      )
      normalize_verdict(response)
    end

    def gateway_payload(asset)
      {
        "gateway" => "photo_review",
        "version" => 1,
        "photo_asset_id" => asset.id,
        "instructions" => INSTRUCTIONS
      }
    end

    def normalize_verdict(response)
      return nil unless response.is_a?(Hash)

      status = response["status"].to_s.strip.downcase.tr(" -", "__")
      return nil unless VERDICT_STATUSES.include?(status)

      recommended = [ true, "true", "yes", 1 ].include?(response["treatment_recommended"])
      {
        "status" => status,
        "notes" => response["notes"].to_s.squish,
        "treatment_recommended" => recommended,
        "treatment_instructions" => recommended ? response["treatment_instructions"].to_s.squish : ""
      }
    end
  end
end
