module Tasks
  class ApplicationController < ::ApplicationController
    private

    def current_task_staff_member
      return nil if session[:tasks_staff_member_id].blank?

      @current_task_staff_member ||= StaffMember.active.find_by(id: session[:tasks_staff_member_id])
    end

    def require_current_task_staff_member!
      current_task_staff_member || raise(ArgumentError, "Select who is completing tasks first.")
    end
  end
end
