import { Controller } from "@hotwired/stimulus"

// Tiny submit-on-change helper.
//
// Used by the photo-required task circle: tapping the circle opens the
// device camera (via the file input's `capture` attribute); as soon as a
// photo is selected, the form auto-submits, Turbo replaces the row.
//
// No targets, no values — wire `change->auto-submit#submit` on whatever
// input should trigger the submit.
export default class extends Controller {
  submit() {
    if (typeof this.element.requestSubmit === "function") {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
