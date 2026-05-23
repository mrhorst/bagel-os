import { Controller } from "@hotwired/stimulus"

// Admin form for a Log Section. Some fields only make sense for "number" type
// (unit_label, decimal places). Show/hide them as the type changes.
export default class extends Controller {
  static targets = ["sectionType", "numberOnly"]

  connect() {
    this.sync()
  }

  sync() {
    const isNumber = this.sectionTypeTarget.value === "number"
    this.numberOnlyTargets.forEach((field) => {
      field.hidden = !isNumber
    })
  }
}
