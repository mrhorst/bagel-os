import { Controller } from "@hotwired/stimulus"

// Sub-field rows manager for a multi-input Log Section. Clones a hidden
// <template> to add a row; lets each row's own controller remove itself.
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(fragment)
    // Focus the new row's label so the user can type immediately.
    const inputs = this.listTarget.querySelectorAll('input[name="log_book_section[fields][][label]"]')
    inputs[inputs.length - 1]?.focus()
  }
}
