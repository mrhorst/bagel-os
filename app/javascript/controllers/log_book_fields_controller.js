import { Controller } from "@hotwired/stimulus"

// Sub-field rows manager for a multi-input Log Section. Clones a hidden
// <template> to add a row, and owns removal so the list can never be emptied:
// a multi-input section must keep at least one input row, so the remove (×)
// affordance is hidden whenever a single row remains. This mirrors the
// server, which seeds a starter row whenever a section has no inputs — the
// inputs list must never be left empty with no row to fill.
export default class extends Controller {
  static targets = ["list", "template", "row"]

  connect() {
    this.refresh()
  }

  add(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(fragment)
    this.refresh()
    // Focus the new row's label so the user can type immediately.
    const inputs = this.listTarget.querySelectorAll('input[name="log_book_section[fields][][label]"]')
    inputs[inputs.length - 1]?.focus()
  }

  remove(event) {
    event.preventDefault()
    // Never remove the last input — a multi-input section needs at least one.
    // (The × is hidden in that state, but guard here too.)
    if (this.rowTargets.length <= 1) return
    event.currentTarget.closest("[data-log-book-fields-target='row']")?.remove()
    this.refresh()
  }

  // Show each row's remove (×) only when removing it would still leave a row
  // behind, so the user can't delete the section's last input into an empty list.
  refresh() {
    const removable = this.rowTargets.length > 1
    this.rowTargets.forEach((row) => {
      const button = row.querySelector(".log-book-fields-row-remove")
      if (button) button.hidden = !removable
    })
  }
}
