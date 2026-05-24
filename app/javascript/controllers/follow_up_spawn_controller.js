import { Controller } from "@hotwired/stimulus"

// Spawn-task form on the follow-up detail page. Toggles the recurring-
// only fields (task list, recurrence type) based on the Kind dropdown.
export default class extends Controller {
  static targets = ["kind", "recurringField"]

  connect() { this.sync() }

  sync() {
    const recurring = this.kindTarget.value === "recurring"
    this.recurringFieldTargets.forEach(el => { el.hidden = !recurring })
  }
}
