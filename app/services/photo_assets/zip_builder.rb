require "zip"

module PhotoAssets
  # Bundles a set of photo assets into an in-memory ZIP: every image plus a
  # manifest.json describing each (caption, notes, tags, uploader). Used by the
  # in-app "Download ZIP" actions and shared with the marketing:export rake task
  # via .manifest_row.
  class ZipBuilder
    def initialize(assets)
      @assets = assets
    end

    # The ZIP as a binary string, ready for send_data.
    def bytes
      manifest = []
      buffer = Zip::OutputStream.write_buffer do |zip|
        @assets.each do |asset|
          next unless asset.photo.attached?

          entry = entry_name(asset)
          zip.put_next_entry(entry)
          zip.write(asset.photo.download)
          manifest << self.class.manifest_row(asset, entry)
        end
        zip.put_next_entry("manifest.json")
        zip.write(JSON.pretty_generate(manifest))
      end
      buffer.string
    end

    def entry_name(asset)
      "photo-#{asset.id}#{asset.photo.filename.extension_with_delimiter}"
    end

    # One manifest entry for a photo. Kept here so the rake export and the
    # in-app export describe assets identically.
    def self.manifest_row(asset, filename)
      {
        id: asset.id,
        file: filename,
        status: asset.status,
        favorite: asset.favorite,
        caption: asset.caption,
        notes: asset.notes,
        tags: asset.confirmed_tags.map(&:slug).sort,
        uploaded_by: asset.uploaded_by&.then { |u| u.name.presence || u.email_address },
        uploaded_at: asset.created_at.iso8601
      }
    end
  end
end
