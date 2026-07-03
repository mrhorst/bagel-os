module PhotoAssetsHelper
  STATUS_BADGE_CLASSES = {
    "needs_review" => "badge-warning",
    "tagged"       => "badge-ok"
  }.freeze

  def photo_status_badge(asset)
    tag.span asset.status_label, class: [ "badge", STATUS_BADGE_CLASSES[asset.status] ]
  end

  # A single tag pill. Reuses the .badge pill style from the design system.
  def tag_pill(name, pending: false)
    tag.span name, class: [ "badge", "tag-pill", ("tag-pill-pending" if pending) ]
  end

  # The active library filters (scope / tag / search / favorites). Threaded
  # from the index into each photo's detail link and back out through its
  # "Back to library" affordance, so opening and closing a photo keeps a
  # reviewer's place in a filtered queue (e.g. "Needs review") instead of
  # dropping them on the unfiltered library — the same place-preservation the
  # Follow-ups queue already does. Only non-blank filters are carried, so the
  # common unfiltered case stays a bare /marketing/photos link (no change).
  def library_filter_params
    params.permit(:scope, :tag, :q, :favorites).to_h.reject { |_, value| value.blank? }
  end

  # The photo detail page is reached from two origins: the library (which
  # threads its active filters, above) and a collection show page. A photo opened
  # from a collection carries from_collection=<id> in its card link so its back
  # affordance returns to that collection instead of overshooting to the library.
  # The id is resolved to a real Collection server-side — never a raw path — so a
  # stale, forged, or missing value simply falls back to the library, the same
  # safe default as a bookmark, deep link, or cold PWA load.
  def photo_back_origin_collection
    return nil if params[:from_collection].blank?

    Collection.find_by(id: params[:from_collection])
  end

  # Phone uploads aren't always variable (e.g. HEIC without libheif); fall
  # back to the original blob rather than raising at render time.
  def photo_asset_image(asset, transform, **options)
    source = asset.photo.variable? ? asset.photo.variant(transform) : asset.photo
    image_tag source, **options
  end
end
