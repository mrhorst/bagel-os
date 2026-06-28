import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "step", "back", "next", "submit", "reviewValue"]
  static values = { errorStep: { type: Number, default: -1 } }

  connect() {
    // Own validation ourselves. The browser's native check blocks a submit on an
    // invalid required field BEFORE the submit event fires — and it can't show a
    // bubble on a field sitting on a hidden panel, so the click silently does
    // nothing. Turning off native validation lets our submit handler run, find
    // the offending step, open it, and report the error where it's visible.
    this.element.noValidate = true

    // After a failed save the server re-renders this form with the offending
    // field's step index. Open there instead of collapsing to step 1, where the
    // error banner would name a field sitting on a hidden panel.
    this.index = this.errorStepValue >= 0 ? this.errorStepValue : 0
    this.showCurrentPanel()
  }

  next() {
    if (!this.currentPanelIsValid()) return

    this.index = Math.min(this.index + 1, this.panelTargets.length - 1)
    this.showCurrentPanel()
  }

  back() {
    this.index = Math.max(this.index - 1, 0)
    this.showCurrentPanel()
  }

  goTo(event) {
    const requestedIndex = event.params.index
    if (requestedIndex > this.index && !this.currentPanelIsValid()) return

    this.index = requestedIndex
    this.showCurrentPanel()
  }

  submit(event) {
    // Validate EVERY panel, not just the current one. The step nav lets a user
    // jump straight to the last step (the "Review" step), skipping a required
    // field like the title on an earlier, now-hidden panel. The browser still
    // blocks the native submit on that invalid field — but it can't show its
    // validation bubble on a hidden control, so the click silently does nothing
    // and the user is stranded with no feedback. Instead, find the first invalid
    // panel, open it, and report the error there so the problem is visible.
    const invalidIndex = this.panelTargets.findIndex(
      (panel) => panel.querySelector(":invalid")
    )
    if (invalidIndex === -1) return

    event.preventDefault()
    this.index = invalidIndex
    this.showCurrentPanel()
    this.panelTargets[invalidIndex].querySelector(":invalid").reportValidity()
  }

  showCurrentPanel() {
    this.panelTargets.forEach((panel, panelIndex) => {
      panel.hidden = panelIndex !== this.index
    })

    this.stepTargets.forEach((step, stepIndex) => {
      step.classList.toggle("task-wizard-step-active", stepIndex === this.index)
      step.classList.toggle("task-wizard-step-complete", stepIndex < this.index)
      step.setAttribute("aria-current", stepIndex === this.index ? "step" : "false")
    })

    this.backTarget.hidden = this.index === 0
    this.nextTarget.hidden = this.index === this.panelTargets.length - 1
    this.submitTarget.hidden = this.index !== this.panelTargets.length - 1

    // The last panel is the Review step. Refill its summary every time it opens
    // so it always reflects the latest entries (the user can jump back, edit,
    // and return via the step nav).
    if (this.index === this.panelTargets.length - 1) this.renderReview()
  }

  // Mirror the entries from the earlier panels into the Review step's summary.
  // Reads straight from the live form controls so it never drifts from what
  // will actually be submitted.
  renderReview() {
    if (!this.hasReviewValueTarget) return

    this.reviewValueTargets.forEach((node) => {
      const text = this.reviewText(node.dataset.taskWizardField)
      node.textContent = text || "—"
      node.classList.toggle("task-wizard-review-empty", !text)
    })
  }

  reviewText(field) {
    if (field === "timing") return this.timingSummary()

    const control = this.fieldControl(field)
    if (!control) return ""

    if (control.tagName === "SELECT") {
      return control.selectedOptions[0]?.value ? control.selectedOptions[0].text.trim() : ""
    }
    return control.value.trim()
  }

  timingSummary() {
    const recurrenceControl = this.fieldControl("recurrence_type")
    if (!recurrenceControl) return ""
    const recurrence = recurrenceControl.value
    const parts = [recurrenceControl.selectedOptions[0]?.text.trim()].filter(Boolean)

    if (recurrence === "one_time") {
      const date = this.fieldControl("one_time_on")?.value
      if (date) parts.push(`on ${date}`)
    }

    if (recurrence === "weekly") {
      const days = this.weekdayAbbreviations()
      if (days.length) parts.push(days.join(", "))
    }

    if (recurrence !== "monthly") {
      const due = this.fieldControl("due_time")?.value
      if (due) parts.push(`due ${this.formatTime(due)}`)
    }

    return parts.join(" · ")
  }

  weekdayAbbreviations() {
    const abbr = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return Array.from(
      this.element.querySelectorAll('input[name="task[weekdays][]"]:checked')
    )
      .map((input) => abbr[Number(input.value)])
      .filter(Boolean)
  }

  formatTime(value) {
    const [hours, minutes] = value.split(":").map(Number)
    if (Number.isNaN(hours) || Number.isNaN(minutes)) return value
    const period = hours >= 12 ? "PM" : "AM"
    const twelveHour = hours % 12 === 0 ? 12 : hours % 12
    return `${twelveHour}:${String(minutes).padStart(2, "0")} ${period}`
  }

  fieldControl(field) {
    return (
      this.element.querySelector(`[name="task[${field}]"]`) ||
      this.element.querySelector(`[name="task[${field}][]"]`)
    )
  }

  currentPanelIsValid() {
    const invalidField = this.panelTargets[this.index].querySelector(":invalid")
    if (!invalidField) return true

    invalidField.reportValidity()
    return false
  }
}
