module FollowUps
  # Keeps the FollowUp record for a LogBookResponse in sync with the
  # current state of the response. Called from the log book save path
  # whenever a response is created or changed.
  #
  # Rules:
  # - response was flagged & still is → update title/urgency if drifted
  # - response newly flagged          → create an open FollowUp
  # - response was flagged, no longer → mark open follow-up as resolved
  # - response was never flagged      → no-op
  class SyncFromLogBookResponse
    def initialize(response, user: nil)
      @response = response
      @user     = user
    end

    def call
      existing = FollowUp.where(origin: @response).order(opened_at: :desc).first

      if @response.flagged_for_follow_up?
        if existing.nil?
          create_follow_up!
        elsif existing.open?
          refresh!(existing)
        elsif existing.resolved?
          # Re-flagged after being resolved — open a brand new follow-up so
          # history shows two distinct events.
          create_follow_up!
        end
      elsif existing&.open?
        existing.resolve!(user: @user, via: "action_taken", note: "Cleared from Log Book.")
      end
    end

    private

    def create_follow_up!
      FollowUp.create!(
        origin:      @response,
        title:       @response.section_title_snapshot.to_s,
        description: description_for(@response),
        urgency:     @response.urgency.presence || "normal",
        opened_by:   @user,
        opened_at:   @response.last_submitted_at || Time.current,
        status:      "open"
      )
    end

    def refresh!(follow_up)
      follow_up.update!(
        title:       @response.section_title_snapshot.to_s,
        description: description_for(@response),
        urgency:     @response.urgency.presence || "normal"
      )
    end

    def description_for(response)
      return response.value_text.presence unless response.multi?
      formatted = response.display_value
      formatted == "Blank" ? nil : formatted
    end
  end
end
