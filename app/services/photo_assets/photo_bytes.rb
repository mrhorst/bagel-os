module PhotoAssets
  # Shared helper for handing a photo asset's image to an AI API: downscale
  # to a JPEG that fits vision input limits, falling back to the original
  # bytes when the blob can't be transformed (e.g. unsupported format).
  module PhotoBytes
    MAX_EDGE = 1568

    module_function

    def jpeg_payload(blob)
      if blob.variable?
        variant = blob.variant(resize_to_limit: [ MAX_EDGE, MAX_EDGE ], format: :jpeg).processed
        [ variant.download, "image/jpeg" ]
      else
        [ blob.download, blob.content_type ]
      end
    rescue ActiveStorage::Error, ActiveStorage::FileNotFoundError, LoadError
      # LoadError: libvips missing on this host — send the original instead.
      [ blob.download, blob.content_type ]
    end
  end
end
