import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "step", "back", "next", "submit"]
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
    // jump straight to the last step (e.g. to "Review"), skipping a required
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
  }

  currentPanelIsValid() {
    const invalidField = this.panelTargets[this.index].querySelector(":invalid")
    if (!invalidField) return true

    invalidField.reportValidity()
    return false
  }
}
