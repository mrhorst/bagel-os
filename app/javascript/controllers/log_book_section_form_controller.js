import { Controller } from "@hotwired/stimulus"

// Admin form for a Log Section. Toggles fields based on the section type:
// - number → unit_label & decimal places visible
// - multi  → sub-fields manager visible (and the single-input number knobs hidden)
export default class extends Controller {
  static targets = ["sectionType", "numberOnly", "multiOnly"]

  connect() {
    this.sync()
  }

  sync() {
    const type = this.sectionTypeTarget.value
    const isNumber = type === "number"
    const isMulti  = type === "multi"

    this.numberOnlyTargets.forEach((el) => { el.hidden = !isNumber })
    this.multiOnlyTargets.forEach((el) => { el.hidden = !isMulti })
  }
}
