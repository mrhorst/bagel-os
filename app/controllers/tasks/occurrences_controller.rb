module Tasks
  class OccurrencesController < ApplicationController
    def show
      @occurrence = TaskOccurrence
        .includes(task_completions: [ :staff_member, :undone_by_staff_member, photo_attachment: :blob ])
        .find(params[:id])
      @active_completion = @occurrence.active_completion
      @undone_completions = @occurrence.undone_completions.includes(photo_attachment: :blob)
      @back_path, @back_label = resolve_back_target(@occurrence)
    end

    private

    # Honor the referer when it's a sibling Tasks page — that's what "back"
    # means to the user. Fall back to the dashboard if we can't tell or the
    # user landed here from outside (deep link, history table, etc.).
    def resolve_back_target(occurrence)
      referer = request.referer
      default = [ tasks_root_path, "Tasks" ]
      return default if referer.blank?

      uri = URI.parse(referer)
      return default if uri.host.present? && uri.host != request.host

      case uri.path
      when tasks_root_path
        [ tasks_root_path, "Tasks" ]
      when tasks_history_path
        [ tasks_history_path, "History" ]
      when %r{\A/tasks/lists/(\d+)\z}
        list = TaskList.find_by(id: Regexp.last_match(1))
        list ? [ tasks_list_path(list), list.name ] : default
      else
        [ referer, "Back" ]
      end
    rescue URI::InvalidURIError
      default
    end
  end
end
