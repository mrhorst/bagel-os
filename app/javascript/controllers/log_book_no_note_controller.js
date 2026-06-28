import { Controller } from "@hotwired/stimulus"

// Per-section interaction polish for the Log Book entry form:
//   • Checking "No note today" blanks the value input and disables it.
//   • Unchecking re-enables it AND restores whatever was typed before — an
//     accidental tap is fully recoverable, never a silent data loss.
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
      if (checked) {
        this.stash(input)
        this.blank(input)
      } else {
        this.restore(input)
      }
      input.disabled = checked
    })
    this.valueFieldTargets.forEach((field) => {
      field.classList.toggle("field-disabled", checked)
    })
  }

  // Remember the current value before blanking it. The server already nils a
  // section's value when "no note" is saved, so blanking here is purely so the
  // card reads as empty — keeping a copy means unchecking can put it back
  // instead of destroying work on a mis-tap.
  stash(input) {
    if (input.type === "checkbox" || input.type === "radio") {
      input.dataset.noNoteStash = input.checked ? "1" : ""
    } else {
      input.dataset.noNoteStash = input.value
    }
  }

  blank(input) {
    if (input.type === "checkbox" || input.type === "radio") {
      input.checked = false
    } else {
      input.value = ""
    }
  }

  restore(input) {
    if (input.dataset.noNoteStash === undefined) return
    if (input.type === "checkbox" || input.type === "radio") {
      input.checked = input.dataset.noNoteStash === "1"
    } else {
      input.value = input.dataset.noNoteStash
    }
    delete input.dataset.noNoteStash
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
