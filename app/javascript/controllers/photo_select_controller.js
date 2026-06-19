import { Controller } from "@hotwired/stimulus"

// Multi-select for the photo library grid. Each card carries a checkbox; the
// bulk action bar reveals itself once anything is checked and shows a running
// count. The whole grid + bar live inside one <form>, so the checked
// photo_asset_ids[] submit straight to the bulk endpoint — no JS plumbing of
// ids needed.
//
// Two ergonomics ride on top of the raw checkboxes so a stray tap can't cost
// you a half-built selection:
//   • Select mode — toggled from the toolbar button. While on, tapping anywhere
//     on a card selects it instead of opening the detail view, so the small
//     checkbox is no longer the only safe target on a phone.
//   • Persistence — the selected ids and the select-mode flag survive a page
//     navigation by riding in sessionStorage, so opening a photo and hitting
//     Back drops you back on the library with the selection (and mode) intact.
//
// Markup:
//   <form data-controller="photo-select"
//         data-action="turbo:submit-start->photo-select#reset">
//     <button data-photo-select-target="toggle"
//             data-action="photo-select#toggleMode">Select</button>
//     <div data-photo-select-target="bar">… <span data-photo-select-target="count"></span></div>
//     <ul>
//       <li class="photo-cell">
//         <input type="checkbox" name="photo_asset_ids[]"
//                data-photo-select-target="checkbox"
//                data-action="change->photo-select#refresh">
//         <a class="photo-card" data-action="photo-select#card">…</a>
//       </li>
//     </ul>
//   </form>
const STORAGE_KEY = "photo-select"

export default class extends Controller {
  static targets = ["checkbox", "bar", "count", "toggle"]
  static values = { mode: Boolean }

  connect() {
    this.restore()
    this.refresh()
  }

  // Tapping a card. In select mode we swallow the navigation and toggle the
  // card's own checkbox instead; otherwise the link opens the photo as usual.
  card(event) {
    if (!this.modeValue) return
    event.preventDefault()
    const checkbox = event.currentTarget
      .closest(".photo-cell")
      ?.querySelector("input[type=checkbox]")
    if (!checkbox) return
    checkbox.checked = !checkbox.checked
    this.refresh()
  }

  toggleMode() {
    this.modeValue = !this.modeValue
    this.refresh()
  }

  selectAll() {
    this.setAll(true)
  }

  clear() {
    this.modeValue = false
    this.setAll(false)
  }

  setAll(checked) {
    this.checkboxTargets.forEach((box) => { box.checked = checked })
    this.refresh()
  }

  // The single place selection state is reflected to the DOM and to storage —
  // every entry point (checkbox change, card tap, toggle, select-all) ends here.
  refresh() {
    const selected = this.selectedCount
    this.element.classList.toggle("has-selection", selected > 0)
    this.element.classList.toggle("select-mode", this.modeValue)
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${selected} selected`
    }
    this.checkboxTargets.forEach((box) => {
      box.closest(".photo-cell")?.classList.toggle("selected", box.checked)
    })
    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = this.modeValue ? "Done" : "Select"
      this.toggleTarget.setAttribute("aria-pressed", String(this.modeValue))
    }
    this.persist()
  }

  // Drop the stored selection as the bulk form submits, so the library reload
  // that follows the action starts clean instead of re-selecting stale ids.
  reset() {
    try { window.sessionStorage?.removeItem(STORAGE_KEY) } catch (_) { /* storage off */ }
  }

  get selectedCount() {
    return this.checkboxTargets.filter((box) => box.checked).length
  }

  get selectedIds() {
    return this.checkboxTargets.filter((box) => box.checked).map((box) => box.value)
  }

  persist() {
    try {
      window.sessionStorage?.setItem(
        STORAGE_KEY,
        JSON.stringify({ ids: this.selectedIds, mode: this.modeValue })
      )
    } catch (_) { /* storage off */ }
  }

  restore() {
    let saved = null
    try {
      saved = JSON.parse(window.sessionStorage?.getItem(STORAGE_KEY) || "null")
    } catch (_) { saved = null }
    if (!saved) return
    if (Array.isArray(saved.ids) && saved.ids.length) {
      const wanted = new Set(saved.ids.map(String))
      this.checkboxTargets.forEach((box) => {
        if (wanted.has(String(box.value))) box.checked = true
      })
    }
    if (saved.mode) this.modeValue = true
  }
}
