import { Controller } from "@hotwired/stimulus"

// Generic popover: a button toggles a panel; the panel closes on outside
// click or Escape. Used for the tasks overflow ⋯ menu and the staff chip.
//
// Markup:
//   <div data-controller="popover">
//     <button data-popover-target="trigger" data-action="popover#toggle">⋯</button>
//     <div data-popover-target="panel" hidden>…</div>
//   </div>
export default class extends Controller {
  static targets = ["panel", "trigger"]

  connect() {
    this.boundDocClick = this.handleDocumentClick.bind(this)
    this.boundKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundDocClick)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.boundDocClick)
    document.addEventListener("keydown", this.boundKeydown)
  }

  close() {
    this.panelTarget.hidden = true
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.boundDocClick)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
