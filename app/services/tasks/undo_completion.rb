module Tasks
  class UndoCompletion
    def initialize(operating_day: OperatingDay.new)
      @operating_day = operating_day
    end

    def call(completion:, user:, note: nil)
      raise ArgumentError, "Signed-in user required." if user.blank?
      raise ArgumentError, "Completion has already been undone." unless completion.active?
      raise ArgumentError, "Completion can only be undone during the same operating day." unless @operating_day.same_day_as?(completion.completed_at)

      completion.update!(
        undone_at: @operating_day.now,
        undone_note: note,
        undone_by_user: user,
        snapshot_undone_by_staff_name: undoer_name(user)
      )
      completion
    end

    private

    def undoer_name(user)
      user.name.presence || user.email_address
    end
  end
end
