class DashboardController < ApplicationController
  def index
    operating_day = Tasks::OperatingDay.new
    daily = operating_day.actionable_daily_scope.includes(:active_completion)
    @tasks_open_today = daily.count { |occurrence| occurrence.status(operating_day: operating_day).in?(%w[open late]) }
    @tasks_late_today = daily.count { |occurrence| occurrence.status(operating_day: operating_day) == "late" }

    @pending_review_count = NormalizationReview.pending.count
    @guide_items_needing_review_count = OrderGuideItem.active.needs_review.count
    @inventory_items_needing_review_count = InventoryItem.active.needs_review.count
    @products_needing_review_count = Product.needs_review.count
    @log_book_follow_up_count = LogBookResponse.unresolved.count
    @marketing_unreviewed_count = PhotoAsset.with_status("unreviewed").count
    @task_briefing = TaskBriefing.find_by(scope_type: "tasks_dashboard", scope_key: "today") if Current.user&.can_access?("tasks")
  end
end
