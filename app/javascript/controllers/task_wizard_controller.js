import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "step", "back", "next", "submit"]

  connect() {
    this.index = 0
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
    if (!this.currentPanelIsValid()) {
      event.preventDefault()
    }
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
