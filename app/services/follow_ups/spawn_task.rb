module FollowUps
  # Convert a follow-up into a task. Two flavors:
  #
  # - one_shot: the task lives in the system "Follow-up tasks" list,
  #   fires once on the chosen date.
  # - recurring: the task lives in any user-chosen list, with a normal
  #   daily/weekly/monthly cadence.
  #
  # In both cases we record a FollowUpTaskLink so the follow-up's detail
  # page can show which tasks were spawned from it.
  class SpawnTask
    SYSTEM_LIST_NAME = "Follow-up tasks".freeze

    Result = Struct.new(:ok, :task, :follow_up, :errors, keyword_init: true) do
      def ok?; ok; end
    end

    def initialize(follow_up, params:, user: nil)
      @follow_up = follow_up
      @params    = params
      @user      = user
    end

    def call
      kind = (@params[:link_kind].presence || "one_shot")
      task = build_task(kind)

      ActiveRecord::Base.transaction do
        task.save!
        FollowUpTaskLink.create!(
          follow_up:  @follow_up,
          task:       task,
          link_kind:  kind,
          created_by: @user
        )

        if ActiveModel::Type::Boolean.new.cast(@params[:auto_resolve])
          @follow_up.resolve!(user: @user, via: "converted_to_task",
            note: "Converted to task: #{task.title}.")
        end
      end

      Result.new(ok: true, task: task, follow_up: @follow_up.reload, errors: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok: false, task: e.record, follow_up: @follow_up, errors: e.record.errors)
    end

    private

    def build_task(kind)
      list = task_list_for(kind)
      title = @params[:title].presence || @follow_up.title

      common = {
        task_list:       list,
        title:           title,
        instructions:    @params[:description].presence || @follow_up.description,
        recurrence_type: kind == "one_shot" ? "one_time" : @params[:recurrence_type].presence || "daily",
        active:          true,
        position:        (list.tasks.maximum(:position).to_i + 1)
      }

      schedule = schedule_attrs(common[:recurrence_type])
      Task.new(common.merge(schedule))
    end

    def task_list_for(kind)
      if kind == "one_shot"
        TaskList.find_or_create_by!(name: SYSTEM_LIST_NAME) do |list|
          list.position = (TaskList.maximum(:position).to_i + 1)
          list.active   = true
        end
      else
        list_id = @params[:task_list_id].presence
        unless list_id
          stub = Task.new
          stub.errors.add(:task_list, "must be selected for a recurring task")
          raise ActiveRecord::RecordInvalid.new(stub)
        end
        TaskList.find(list_id)
      end
    end

    def schedule_attrs(recurrence_type)
      today = Date.current
      due   = @params[:due_time].presence || "17:00"

      case recurrence_type
      when "one_time"
        { one_time_on: @params[:one_time_on].presence || today, due_time: due }
      when "daily"
        { starts_on: today, due_time: due }
      when "weekly"
        { starts_on: today, due_time: due, weekdays: Array(@params[:weekdays]).map(&:to_i) }
      when "monthly"
        { starts_on: today, due_time: due }
      end
    end
  end
end
