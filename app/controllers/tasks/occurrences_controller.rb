module Tasks
  class OccurrencesController < ApplicationController
    def show
      @occurrence = TaskOccurrence
        .includes(task_completions: [ :user, :undone_by_user, photo_attachment: :blob ])
        .find(params[:id])
      @active_completion = @occurrence.active_completion
      @undone_completions = @occurrence.undone_completions.includes(photo_attachment: :blob)
      @back_path, @back_label = resolve_back_target(@occurrence)
    end

    private

    # Where the back arrow points. Prefer an explicit ?back= (the complete/undo
    # forms carry it, so it survives the full-page submit that reloads this page
    # with its OWN url as the referer); otherwise honor the referer of a normal
    # arrival; otherwise fall back to the dashboard.
    def resolve_back_target(occurrence)
      explicit = internal_tasks_path(params[:back])
      return target_for(explicit) if explicit

      referer = request.referer
      return default_back_target if referer.blank?

      uri = URI.parse(referer)
      return default_back_target if uri.host.present? && uri.host != request.host

      # Completing or undoing on this page submits a full-page form (turbo: false)
      # that redirect_backs here, so the reloaded page's referer is THIS page.
      # Never let "back" point at the page it's on — that's a dead-end loop where
      # the arrow appears to do nothing. Fall back to the dashboard instead.
      return default_back_target if uri.path == request.path

      target_for(uri.path)
    rescue URI::InvalidURIError
      default_back_target
    end

    # Map a same-origin Tasks path to the [path, label] the back arrow shows.
    def target_for(path)
      case path
      when tasks_root_path
        [ tasks_root_path, "Tasks" ]
      when tasks_history_path
        [ tasks_history_path, "History" ]
      when %r{\A/tasks/lists/(\d+)\z}
        list = TaskList.find_by(id: Regexp.last_match(1))
        list ? [ tasks_list_path(list), list.name ] : default_back_target
      else
        [ path, "Back" ]
      end
    end

    def default_back_target
      [ tasks_root_path, "Tasks" ]
    end

    # Accept a ?back= value only if it's a bare local Tasks path (no host, no
    # scheme) that isn't this page itself — so the arrow can't be pointed
    # off-site or back into the dead-end loop guarded against above.
    def internal_tasks_path(raw)
      return nil if raw.blank?

      uri = URI.parse(raw)
      return nil if uri.host.present? || uri.scheme.present?
      return nil unless uri.path.start_with?("/tasks")
      return nil if uri.path == request.path

      uri.path
    rescue URI::InvalidURIError
      nil
    end
  end
end
