import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["control", "summary", "insight", "panel"]
  static values = { initialMode: String }

  connect() {
    this.showMode(this.initialModeValue || "package_price")
  }

  setMode(event) {
    event.preventDefault()
    this.showMode(event.currentTarget.dataset.chartMode, event.currentTarget.href)
  }

  showMode(mode, href) {
    this.controlTargets.forEach((control) => {
      const active = control.dataset.chartMode === mode
      control.classList.toggle("active", active)
      control.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.summaryTargets.forEach((summary) => {
      summary.hidden = summary.dataset.chartMode !== mode
    })

    this.insightTargets.forEach((insight) => {
      insight.hidden = insight.dataset.chartMode !== mode
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.chartMode !== mode
    })

    if (window.Chartkick) window.Chartkick.eachChart((chart) => chart.redraw())

    if (href) window.history.replaceState({}, "", href)
  }
}
