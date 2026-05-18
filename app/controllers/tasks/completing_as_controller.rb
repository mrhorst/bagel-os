module Tasks
  class CompletingAsController < ApplicationController
    def update
      staff_member = StaffMember.active.find_by(id: params[:staff_member_id].presence)
      session[:tasks_staff_member_id] = staff_member&.id

      redirect_back fallback_location: tasks_root_path, notice: completing_as_notice(staff_member)
    end

    private

    def completing_as_notice(staff_member)
      return "Cleared task staff selection." if staff_member.blank?

      "Completing tasks as #{staff_member.display_name}."
    end
  end
end
