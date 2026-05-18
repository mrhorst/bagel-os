import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recurrence", "oneTime", "recurring", "weekly", "dueTime"]

  connect() {
    this.sync()
  }

  sync() {
    const recurrence = this.recurrenceTarget.value
    this.toggle(this.oneTimeTargets, recurrence === "one_time")
    this.toggle(this.recurringTargets, recurrence !== "one_time")
    this.toggle(this.weeklyTargets, recurrence === "weekly")
    this.toggle(this.dueTimeTargets, recurrence !== "monthly")
  }

  toggle(targets, isVisible) {
    targets.forEach((target) => {
      target.hidden = !isVisible
    })
  }
}
