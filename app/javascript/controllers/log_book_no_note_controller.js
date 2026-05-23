import { Controller } from "@hotwired/stimulus"

// Per-section interaction polish for the Log Book entry form:
//   • Checking "No note today" clears the value input and disables it.
//   • Unchecking re-enables it.
//   • Flagging follow-up reveals the urgency segmented row; unflagging hides
//     it and resets to "normal".
export default class extends Controller {
  static targets = ["valueField", "input", "flagCheckbox", "urgency"]

  connect() {
    // No-op: we react to user clicks, not initial state.
  }

  toggle(event) {
    const checked = event.target.checked
    this.inputTargets.forEach((input) => {
      input.disabled = checked
      if (!checked) return
      if (input.type === "checkbox" || input.type === "radio") {
        input.checked = false
      } else {
        input.value = ""
      }
    })
    this.valueFieldTargets.forEach((field) => {
      field.classList.toggle("field-disabled", checked)
    })
  }

  toggleFlag(event) {
    if (!this.hasUrgencyTarget) return
    const checked = event.target.checked
    this.urgencyTarget.hidden = !checked
    if (!checked) {
      this.urgencyTarget.querySelectorAll("input[type=radio]").forEach((radio) => {
        radio.checked = radio.value === "normal"
      })
    }
  }
}
