module Tasks
  class LiveUpdates
    STREAM = "tasks:today".freeze
    BRIEFING_REFRESH_DELAY = 30.seconds

    def self.task_state_changed!
      refresh_briefing_later
      broadcast!
    end

    def self.refresh_briefing_later(wait: BRIEFING_REFRESH_DELAY)
      GenerateBriefingJob.set(wait: wait).perform_later
    end

    def self.broadcast!
      Turbo::StreamsChannel.broadcast_refresh_later_to(STREAM)
    end
  end
end
