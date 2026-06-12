require "anthropic"

module PhotoAssets
  # First-pass review of a photo asset by Claude: judges whether the shot is
  # usable for marketing, what needs fixing, and whether a light AI treatment
  # (background cleanup, dirty plate) would make it usable. Staff can always
  # override the verdict from the photo's page.
  class AiReviewer
    DEFAULT_MODEL = "claude-opus-4-8".freeze

    VERDICT_SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[status notes treatment_recommended treatment_instructions],
      properties: {
        status: { type: "string", enum: %w[approved needs_work rejected] },
        notes: { type: "string", description: "1-3 plain sentences for restaurant staff: what works, what to fix or why it was rejected." },
        treatment_recommended: { type: "boolean", description: "True only when a light edit (clean background clutter, wipe a dirty plate or smudge) would clearly help. Never to alter the food itself." },
        treatment_instructions: { type: "string", description: "Short edit instructions when treatment is recommended, otherwise empty." }
      }
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You review photos for a restaurant's marketing library (menus, social media, website).
      Judge each photo on: focus and lighting, composition, cleanliness (dirty plates,
      smudges, messy or distracting backgrounds), and whether the food looks appetizing
      and realistic.

      Statuses:
      - approved: usable as-is, or usable after a light cleanup edit.
      - needs_work: a reshoot would fix it; give concrete guidance (angle, light, staging).
      - rejected: not usable for marketing (out of focus, unappetizing, wrong subject).

      Recommend treatment only for issues an edit can fix without touching the food:
      background clutter, dirty plate rims, counter smudges. Keep everything realistic —
      no replacing or beautifying the food itself.
    PROMPT

    def self.configured?
      ENV["ANTHROPIC_API_KEY"].present?
    end

    def initialize(client: nil, model: ENV.fetch("MARKETING_AI_REVIEW_MODEL", DEFAULT_MODEL))
      @client = client
      @model = model
    end

    # Reviews and applies the verdict. Returns the verdict hash, or nil when
    # the API is unavailable or declines (asset stays unreviewed for a human).
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

    attr_reader :model

    def client
      @client ||= Anthropic::Client.new
    end

    def fetch_verdict(asset)
      data, media_type = PhotoBytes.jpeg_payload(asset.photo)

      message = client.messages.create(
        model: model,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [ {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: media_type, data: Base64.strict_encode64(data) } },
            { type: "text", text: "Review this photo for the marketing library. Photo ##{asset.id}." }
          ]
        } ],
        output_config: { format: { type: "json_schema", schema: VERDICT_SCHEMA } }
      )

      return nil if message.stop_reason.to_s == "refusal"

      text = message.content.find { |block| block.type.to_s == "text" }
      return nil if text.nil?

      JSON.parse(text.text)
    rescue Anthropic::Errors::APIError, JSON::ParserError => error
      Rails.logger.warn("AI photo review failed for photo asset #{asset.id}: #{error.class}: #{error.message}")
      nil
    end
  end
end
