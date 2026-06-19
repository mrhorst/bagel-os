# Active Storage renders image variants (thumbnails, previews) with libvips by
# default. A host without libvips installed renders every variant as a broken
# image, so fall back to ImageMagick when libvips isn't usable. libvips stays
# preferred when present — it's faster and lighter.
#
# We set config.active_storage.variant_processor (not ActiveStorage.variant_
# processor directly) because Active Storage applies that config value in an
# after_initialize hook that would otherwise overwrite a direct assignment.

libvips_usable =
  begin
    require "vips"
    true
  rescue LoadError
    false
  end

unless libvips_usable
  imagemagick_usable = %w[magick convert].any? do |bin|
    ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, bin)) }
  end

  if imagemagick_usable
    Rails.application.config.active_storage.variant_processor = :mini_magick
    Rails.logger.info("[active_storage] libvips not found — using ImageMagick (mini_magick) for image variants")
  else
    Rails.logger.warn("[active_storage] neither libvips nor ImageMagick found — image variants will not render")
  end
end
