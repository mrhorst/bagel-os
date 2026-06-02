module Tasks
  class GenerateBriefingJob < ApplicationJob
    queue_as :background

    def perform(now: Time.current)
      operating_day = OperatingDay.new(now: now)
      today = operating_day.today

      OccurrenceBuilder.new(operating_day: operating_day).build!(from: today, to: today)
      OccurrenceBuilder.new(operating_day: operating_day).build!(from: today.beginning_of_month, to: today.end_of_month)

      BriefingGenerator.new(operating_day: operating_day).find_or_generate!
    end
  end
end
