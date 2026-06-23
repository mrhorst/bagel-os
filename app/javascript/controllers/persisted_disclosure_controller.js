import { Controller } from "@hotwired/stimulus"

// Persists a native <details> open/closed state in localStorage, scoped to a
// key (e.g. a list id), so the choice survives Turbo Drive navigations AND
// Turbo 8 broadcast morph refreshes — both of which would otherwise reset the
// element back to its server-rendered default.
//
// Progressive enhancement: with no JS the <details> still works; this only
// remembers the user's last choice.
//
// Markup:
//   <details data-controller="persisted-disclosure"
//            data-action="toggle->persisted-disclosure#save"
//            data-persisted-disclosure-key-value="tasks:completed-disclosure:42">
export default class extends Controller {
  static values = { key: String }

  connect() {
    this.restore()
    // During a broadcast morph, idiomorph would morph our `open` attribute back
    // to the server default. Veto that one attribute so the user's choice holds.
    this.boundBeforeMorphAttr = this.handleBeforeMorphAttribute.bind(this)
    this.element.addEventListener("turbo:before-morph-attribute", this.boundBeforeMorphAttr)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.boundBeforeMorphAttr)
  }

  save() {
    if (!this.hasKeyValue) return
    try {
      window.localStorage.setItem(this.keyValue, this.element.open ? "1" : "0")
    } catch (_e) {
      // localStorage can be unavailable (private mode, quota); ignore.
    }
  }

  restore() {
    if (!this.hasKeyValue) return
    let stored
    try {
      stored = window.localStorage.getItem(this.keyValue)
    } catch (_e) {
      return
    }
    if (stored === null) return
    this.element.open = stored === "1"
  }

  handleBeforeMorphAttribute(event) {
    if (event.detail && event.detail.attributeName === "open") {
      event.preventDefault()
    }
  }
}
