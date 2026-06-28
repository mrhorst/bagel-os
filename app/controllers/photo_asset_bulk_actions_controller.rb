class PhotoAssetBulkActionsController < ApplicationController
  require_module_access :marketing

  ACTIONS = %w[favorite unfavorite add_tag add_to_collection delete].freeze

  # One endpoint for the library's multi-select toolbar. The submitted
  # +bulk_action+ button decides what happens to the checked +photo_asset_ids+.
  def create
    assets = PhotoAsset.where(id: selected_ids)
    action = params[:bulk_action].to_s

    if assets.empty?
      return redirect_back_to_library(alert: "Select at least one photo first.")
    end
    unless ACTIONS.include?(action)
      return redirect_back_to_library(alert: "That bulk action isn't available.")
    end

    level, message = perform(action, assets)
    redirect_back_to_library(level => message)
  end

  private

  def selected_ids
    Array(params[:photo_asset_ids]).map(&:to_i).reject(&:zero?)
  end

  # Returns a [flash_level, message] pair so the action can render a real
  # failure (e.g. nothing chosen in the Tag/Collection dropdown) through the
  # warn-toned :alert channel rather than the green :notice "success" one.
  def perform(action, assets)
    case action
    when "favorite"          then [ :notice, set_favorite(assets, true) ]
    when "unfavorite"        then [ :notice, set_favorite(assets, false) ]
    when "delete"            then [ :notice, delete_assets(assets) ]
    when "add_tag"           then add_tag(assets)
    when "add_to_collection" then add_to_collection(assets)
    end
  end

  def set_favorite(assets, value)
    count = assets.update_all(favorite: value)
    "#{pluralize_photos(count)} #{value ? "added to" : "removed from"} favorites."
  end

  def delete_assets(assets)
    count = assets.to_a.each(&:destroy!).size
    "#{pluralize_photos(count)} deleted."
  end

  def add_tag(assets)
    tag = Tag.active.find_by(id: params[:tag_id])
    return [ :alert, "Choose a tag to apply." ] if tag.nil?

    tagged = 0
    assets.find_each do |asset|
      tagging = asset.taggings.find_or_initialize_by(tag: tag)
      # A photo already carrying this confirmed tag is unchanged — skip it so it
      # isn't counted as a fresh tag. A pending AI suggestion still counts: the
      # manual apply confirms it, which is a real state change.
      next if tagging.persisted? && tagging.confirmed?

      tagging.source = "manual" if tagging.new_record?
      tagging.confirmed_at ||= Time.current
      tagging.created_by ||= Current.user
      tagging.save!
      tagged += 1
    end

    # Report what actually changed, not how many were selected: photos already
    # carrying the tag are skipped above, so counting the whole selection would
    # claim a fresh tag that never happened. Mirrors #add_to_collection.
    if tagged.zero?
      [ :notice, "Those photos already have #{tag.name}." ]
    else
      [ :notice, "Tagged #{pluralize_photos(tagged)} #{tag.name}." ]
    end
  end

  def add_to_collection(assets)
    collection = Collection.find_by(id: params[:collection_id])
    return [ :alert, "Choose a collection." ] if collection.nil?

    next_position = (collection.collection_memberships.maximum(:position) || 0)
    added = 0
    assets.find_each do |asset|
      membership = collection.collection_memberships.find_or_initialize_by(photo_asset: asset)
      next unless membership.new_record?

      membership.added_by = Current.user
      membership.position = (next_position += 1)
      membership.save!
      added += 1
    end

    # Report what actually changed, not how many were selected: photos already
    # in the collection are skipped above, so counting the whole selection would
    # claim a fresh add that never happened.
    if added.zero?
      [ :notice, "Those photos are already in #{collection.name}." ]
    else
      [ :notice, "Added #{pluralize_photos(added)} to #{collection.name}." ]
    end
  end

  def pluralize_photos(count)
    "#{count} #{"photo".pluralize(count)}"
  end

  def redirect_back_to_library(**flash_opts)
    redirect_back fallback_location: photo_assets_path, **flash_opts
  end
end
