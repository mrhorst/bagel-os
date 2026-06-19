# Pull photo assets out of the library for marketing work. Writes the image
# files plus a manifest.json describing each (caption, notes, tags, uploader).
#
#   bin/rails marketing:export                          # everything -> tmp/marketing_export
#   bin/rails marketing:export STATUS=tagged            # one status (pending|needs_review|tagged)
#   bin/rails marketing:export TAG=food                 # only photos confirmed-tagged "food"
#   bin/rails marketing:export TAG=food DIR=/path/out   # custom output dir
namespace :marketing do
  desc "Export photo assets and a manifest.json (STATUS=all|pending|needs_review|tagged, TAG=slug, DIR=tmp/marketing_export)"
  task export: :environment do
    status = ENV.fetch("STATUS", "all")
    unless status == "all" || PhotoAsset::STATUSES.include?(status)
      abort "Unknown STATUS #{status.inspect}. Use one of: all, #{PhotoAsset::STATUSES.join(', ')}"
    end

    dir = Pathname(ENV.fetch("DIR", "tmp/marketing_export"))
    FileUtils.mkdir_p(dir)

    scope = status == "all" ? PhotoAsset.all : PhotoAsset.with_status(status)
    scope = scope.tagged_with(ENV["TAG"]) if ENV["TAG"].present?

    manifest = scope.with_attached_photo.includes(confirmed_tags: []).recent_first.map do |asset|
      blob = asset.photo
      filename = "photo-#{asset.id}#{blob.filename.extension_with_delimiter}"
      File.binwrite(dir.join(filename), blob.download)
      PhotoAssets::ZipBuilder.manifest_row(asset, filename)
    end

    File.write(dir.join("manifest.json"), JSON.pretty_generate(manifest))
    puts "Exported #{manifest.size} photo(s) (#{status}#{", tag=#{ENV['TAG']}" if ENV['TAG'].present?}) to #{dir}"
  end
end
