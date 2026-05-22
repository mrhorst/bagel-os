module Tasks
  class CompleteOccurrence
    def initialize(operating_day: OperatingDay.new)
      @operating_day = operating_day
    end

    def call(occurrence:, staff_member:, notes: nil, photo: nil)
      raise ArgumentError, "Staff member must be active." unless staff_member&.active?
      raise ArgumentError, "Task occurrence is already completed." if occurrence.active_completion.present?
      raise ArgumentError, "Missed tasks cannot be completed." unless occurrence.completable?(operating_day: @operating_day)

      TaskCompletion.transaction do
        completion = occurrence.task_completions.build(
          staff_member: staff_member,
          snapshot_staff_name: staff_member.display_name,
          completed_at: @operating_day.now,
          notes: notes
        )
        completion.photo.attach(photo) if photo.present?
        completion.save!
        completion
      end
    end
  end
end
