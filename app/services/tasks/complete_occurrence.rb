module Tasks
  class CompleteOccurrence
    def initialize(operating_day: OperatingDay.new)
      @operating_day = operating_day
    end

    def call(occurrence:, user:, notes: nil, photo: nil)
      raise ArgumentError, "Signed-in user required." if user.blank?
      raise ArgumentError, "Task occurrence is already completed." if occurrence.active_completion.present?
      raise ArgumentError, "Missed tasks cannot be completed." unless occurrence.completable?(operating_day: @operating_day)

      TaskCompletion.transaction do
        completion = occurrence.task_completions.build(
          user: user,
          snapshot_staff_name: completer_name(user),
          completed_at: @operating_day.now,
          notes: notes
        )
        completion.photo.attach(photo) if photo.present?
        completion.save!
        completion
      end
    end

    private

    def completer_name(user)
      user.name.presence || user.email_address
    end
  end
end
