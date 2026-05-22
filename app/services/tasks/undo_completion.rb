module Tasks
  class UndoCompletion
    def initialize(operating_day: OperatingDay.new)
      @operating_day = operating_day
    end

    def call(completion:, staff_member:, note: nil)
      raise ArgumentError, "Staff member must be active." unless staff_member&.active?
      raise ArgumentError, "Completion has already been undone." unless completion.active?
      raise ArgumentError, "Completion can only be undone during the same operating day." unless @operating_day.same_day_as?(completion.completed_at)

      completion.update!(
        undone_at: @operating_day.now,
        undone_note: note,
        undone_by_staff_member: staff_member,
        snapshot_undone_by_staff_name: staff_member.display_name
      )
      completion
    end
  end
end
