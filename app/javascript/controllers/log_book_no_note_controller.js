import { Controller } from "@hotwired/stimulus"

// Per-section interaction polish for the Log Book entry form:
//   • Checking "No note today" blanks the value input and disables it.
//   • Unchecking re-enables it AND restores whatever was typed before — an
//     accidental tap is fully recoverable, never a silent data loss.
//   • Flagging follow-up reveals the urgency segmented row; unflagging hides
//     it and resets to "normal" BUT stashes the chosen urgency so re-flagging
//     restores it — an accidental untap is never a silent downgrade.
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
    const radios = this.urgencyTarget.querySelectorAll("input[type=radio]")
    if (checked) {
      // Re-flagging: bring back whatever urgency was chosen before an unflag
      // reset it, so an accidental untap is fully recoverable — the same
      // non-destructive guarantee `toggle` gives the value inputs above.
      this.restoreUrgency(radios)
    } else {
      // Unflagging resets to "normal" so an unflagged response carries no
      // urgency — but stash the prior choice first. Without this, an accidental
      // untap (then re-tap) silently downgrades the urgency for good: the
      // form's autosave persists the reset to the server.
      this.stashUrgency(radios)
      radios.forEach((radio) => { radio.checked = radio.value === "normal" })
    }
  }

  stashUrgency(radios) {
    const chosen = Array.from(radios).find((radio) => radio.checked)
    this.urgencyTarget.dataset.urgencyStash = chosen ? chosen.value : ""
  }

  restoreUrgency(radios) {
    const stashed = this.urgencyTarget.dataset.urgencyStash
    if (!stashed) return // nothing stashed, or it was already "normal"
    radios.forEach((radio) => { radio.checked = radio.value === stashed })
    delete this.urgencyTarget.dataset.urgencyStash
  }
}
