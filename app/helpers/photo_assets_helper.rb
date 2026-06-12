module PhotoAssetsHelper
  STATUS_BADGE_CLASSES = {
    "approved"   => "badge-ok",
    "needs_work" => "badge-warning",
    "rejected"   => "badge-danger"
  }.freeze

  def photo_status_badge(asset)
    tag.span asset.status_label, class: [ "badge", STATUS_BADGE_CLASSES[asset.status] ]
  end

  # Phone uploads aren't always variable (e.g. HEIC without libheif); fall
  # back to the original blob rather than raising at render time.
  def photo_asset_image(asset, transform, **options)
    source = asset.photo.variable? ? asset.photo.variant(transform) : asset.photo
    image_tag source, **options
  end
end
