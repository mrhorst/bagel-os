# Pull photo assets out of the library for marketing work (or for an agent
# to review). Writes the image files plus a manifest.json describing each.
#
#   bin/rails marketing:export                          # approved photos -> tmp/marketing_export
#   bin/rails marketing:export STATUS=needs_work        # one status
#   bin/rails marketing:export STATUS=all DIR=/path/out # everything, custom dir
#   bin/rails marketing:export PHOTOS=original          # ignore AI-treated copies
#
# Each photo exports its publishable image: the AI-treated copy when one
# exists, otherwise the original (PHOTOS=original forces originals).
namespace :marketing do
  desc "Export photo assets and a manifest.json (STATUS=approved|unreviewed|needs_work|rejected|all, DIR=tmp/marketing_export, PHOTOS=publishable|original)"
  task export: :environment do
    status = ENV.fetch("STATUS", "approved")
    unless status == "all" || PhotoAsset::STATUSES.include?(status)
      abort "Unknown STATUS #{status.inspect}. Use one of: all, #{PhotoAsset::STATUSES.join(', ')}"
    end

    originals_only = ENV["PHOTOS"] == "original"
    dir = Pathname(ENV.fetch("DIR", "tmp/marketing_export"))
    FileUtils.mkdir_p(dir)

    scope = status == "all" ? PhotoAsset.all : PhotoAsset.with_status(status)
    manifest = scope.with_attached_photo.recent_first.map do |asset|
      blob = originals_only ? asset.photo : asset.publishable_photo
      treated = !originals_only && asset.treated_photo.attached?
      filename = "photo-#{asset.id}-#{asset.status.dasherize}#{'-treated' if treated}#{blob.filename.extension_with_delimiter}"
      File.binwrite(dir.join(filename), blob.download)
      {
        id: asset.id,
        file: filename,
        status: asset.status,
        treated: treated,
        caption: asset.caption,
        notes: asset.notes,
        reviewed_via: asset.reviewed_via,
        uploaded_by: asset.uploaded_by&.then { |u| u.name.presence || u.email_address },
        uploaded_at: asset.created_at.iso8601
      }
    end

    File.write(dir.join("manifest.json"), JSON.pretty_generate(manifest))
    puts "Exported #{manifest.size} photo(s) (#{status}) to #{dir}"
  end
end
