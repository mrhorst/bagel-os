import { Controller } from "@hotwired/stimulus"

// Spawn-task form on the follow-up detail page. Shows the right fields
// based on Kind (one-shot vs recurring) and the recurrence cadence.
export default class extends Controller {
  static targets = ["kind", "recurrence", "oneShotField", "recurringField", "weeklyField"]

  connect() { this.sync() }

  sync() {
    const recurring = this.kindTarget.value === "recurring"
    this.oneShotFieldTargets.forEach(el => { el.hidden = recurring })
    this.recurringFieldTargets.forEach(el => { el.hidden = !recurring })

    const weekly = recurring && this.hasRecurrenceTarget && this.recurrenceTarget.value === "weekly"
    this.weeklyFieldTargets.forEach(el => { el.hidden = !weekly })
  }
}
