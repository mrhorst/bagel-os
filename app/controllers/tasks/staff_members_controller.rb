module Tasks
  class StaffMembersController < ApplicationController
    def index
      @staff_members = StaffMember.ordered
    end

    def create
      staff_member = StaffMember.new(staff_member_params)

      if staff_member.save
        redirect_to tasks_manage_staff_index_path, notice: "Staff member created."
      else
        redirect_to tasks_manage_staff_index_path, alert: staff_member.errors.full_messages.to_sentence
      end
    end

    def update
      staff_member = StaffMember.find(params[:id])

      if staff_member.update(staff_member_params)
        redirect_to tasks_manage_staff_index_path, notice: "Staff member updated."
      else
        redirect_to tasks_manage_staff_index_path, alert: staff_member.errors.full_messages.to_sentence
      end
    end

    def deactivate
      StaffMember.find(params[:id]).deactivate!
      redirect_to tasks_manage_staff_index_path, notice: "Staff member deactivated."
    end

    def reactivate
      StaffMember.find(params[:id]).reactivate!
      redirect_to tasks_manage_staff_index_path, notice: "Staff member reactivated."
    end

    private

    def staff_member_params
      params.require(:staff_member).permit(:display_name, :notes)
    end
  end
end
