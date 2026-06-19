class DashboardController < ApplicationController
  def index
    operating_day = Tasks::OperatingDay.new
    daily = operating_day.actionable_daily_scope.includes(:active_completion).to_a

    # Only count lists the user can actually open right now. Lists past their
    # display window are unreachable on the Tasks screen, so flagging their
    # tasks as "late" here would just be noise the user can't act on. Lists not
    # open yet surface separately as "upcoming".
    visible_ids = TaskList.visible_ids_at(operating_day.now)
    upcoming_ids = TaskList.upcoming_ids_at(operating_day.now)

    visible_now = daily.select { |occurrence| visible_ids.include?(occurrence.task_list_id) }
    @tasks_open_today = visible_now.count { |occurrence| occurrence.status(operating_day: operating_day).in?(%w[open late]) }
    @tasks_late_today = visible_now.count { |occurrence| occurrence.status(operating_day: operating_day) == "late" }
    @tasks_upcoming_today = daily.count do |occurrence|
      upcoming_ids.include?(occurrence.task_list_id) &&
        occurrence.status(operating_day: operating_day).in?(%w[open late])
    end

    @pending_review_count = NormalizationReview.pending.count
    @guide_items_needing_review_count = OrderGuideItem.active.needs_review.count
    @inventory_items_needing_review_count = InventoryItem.active.needs_review.count
    @products_needing_review_count = Product.needs_review.count
    @log_book_follow_up_count = LogBookResponse.unresolved.count
    @marketing_unreviewed_count = PhotoAsset.with_status("unreviewed").count
    @task_briefing = TaskBriefing.find_by(scope_type: "tasks_dashboard", scope_key: "today") if Current.user&.can_access?("tasks")
  end
end
