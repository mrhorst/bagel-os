import { Controller } from "@hotwired/stimulus"

// One sub-field row inside a multi-input section. Hides number-only
// columns (unit, decimals) unless the row's type is "number". Handles
// its own removal.
export default class extends Controller {
  static targets = ["type", "numberOnly"]

  connect() { this.sync() }

  sync() {
    const isNumber = this.typeTarget.value === "number"
    this.numberOnlyTargets.forEach((el) => { el.hidden = !isNumber })
  }

  remove(event) {
    event.preventDefault()
    this.element.remove()
  }
}
