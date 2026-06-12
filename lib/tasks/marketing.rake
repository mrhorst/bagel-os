# Pull photo assets out of the library for marketing work (or for an agent
# to review). Writes the image files plus a manifest.json describing each.
#
#   bin/rails marketing:export                          # approved photos -> tmp/marketing_export
#   bin/rails marketing:export STATUS=needs_work        # one status
#   bin/rails marketing:export STATUS=all DIR=/path/out # everything, custom dir
namespace :marketing do
  desc "Export photo assets and a manifest.json (STATUS=approved|unreviewed|needs_work|rejected|all, DIR=tmp/marketing_export)"
  task export: :environment do
    status = ENV.fetch("STATUS", "approved")
    unless status == "all" || PhotoAsset::STATUSES.include?(status)
      abort "Unknown STATUS #{status.inspect}. Use one of: all, #{PhotoAsset::STATUSES.join(', ')}"
    end

    dir = Pathname(ENV.fetch("DIR", "tmp/marketing_export"))
    FileUtils.mkdir_p(dir)

    scope = status == "all" ? PhotoAsset.all : PhotoAsset.with_status(status)
    manifest = scope.with_attached_photo.recent_first.map do |asset|
      filename = "photo-#{asset.id}-#{asset.status.dasherize}#{asset.photo.filename.extension_with_delimiter}"
      File.binwrite(dir.join(filename), asset.photo.download)
      {
        id: asset.id,
        file: filename,
        status: asset.status,
        caption: asset.caption,
        notes: asset.notes,
        uploaded_by: asset.uploaded_by&.then { |u| u.name.presence || u.email_address },
        uploaded_at: asset.created_at.iso8601
      }
    end

    File.write(dir.join("manifest.json"), JSON.pretty_generate(manifest))
    puts "Exported #{manifest.size} photo(s) (#{status}) to #{dir}"
  end
end
