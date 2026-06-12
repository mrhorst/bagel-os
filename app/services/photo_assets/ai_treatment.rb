module PhotoAssets
  # Produces a lightly edited copy of a photo (clear background clutter,
  # clean a dirty plate) via the agent gateway's image-capable model,
  # attached as a separate treated_photo. The original is never modified.
  class AiTreatment
    BASE_INSTRUCTIONS = <<~PROMPT.freeze
      Edit this restaurant marketing photo and return the edited image.
      Remove background clutter and clean any dirty plate rims, smudges, or
      stains on surfaces. Keep the photo photorealistic: do not change,
      replace, or beautify the food itself, and keep the original lighting,
      colors, framing, and composition.
    PROMPT

    def self.configured?
      TreatmentGatewayClient.new.configured?
    end

    def initialize(gateway_client: TreatmentGatewayClient.new)
      @gateway_client = gateway_client
    end

    # Returns true when a treated photo was attached.
    def treat!(asset)
      return false unless gateway_client.configured?

      data, media_type = PhotoBytes.jpeg_payload(asset.photo)
      result = gateway_client.call(
        prompt_for(asset),
        image_base64: Base64.strict_encode64(data),
        image_mime: media_type
      )
      if result.nil?
        Rails.logger.warn("Photo treatment returned no image for photo asset #{asset.id}")
        return false
      end

      bytes, mime = result
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

    attr_reader :gateway_client

    def prompt_for(asset)
      specific = asset.treatment_instructions.to_s.strip
      specific.present? ? "#{BASE_INSTRUCTIONS}\nSpecifically: #{specific}" : BASE_INSTRUCTIONS
    end
  end
end
