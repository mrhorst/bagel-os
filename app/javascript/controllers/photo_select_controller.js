import { Controller } from "@hotwired/stimulus"

// Multi-select for the photo library grid. Each card carries a checkbox; the
// bulk action bar reveals itself once anything is checked and shows a running
// count. The whole grid + bar live inside one <form>, so the checked
// photo_asset_ids[] submit straight to the bulk endpoint — no JS plumbing of
// ids needed.
//
// Markup:
//   <form data-controller="photo-select">
//     <div data-photo-select-target="bar">… <span data-photo-select-target="count"></span></div>
//     <ul>
//       <li><input type="checkbox" name="photo_asset_ids[]"
//                  data-photo-select-target="checkbox"
//                  data-action="change->photo-select#refresh"> … </li>
//     </ul>
//   </form>
export default class extends Controller {
  static targets = ["checkbox", "bar", "count"]

  connect() {
    this.refresh()
  }

  refresh() {
    const selected = this.selectedCount
    this.element.classList.toggle("has-selection", selected > 0)
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${selected} selected`
    }
    this.checkboxTargets.forEach((box) => {
      box.closest(".photo-cell")?.classList.toggle("selected", box.checked)
    })
  }

  selectAll() {
    this.setAll(true)
  }

  clear() {
    this.setAll(false)
  }

  setAll(checked) {
    this.checkboxTargets.forEach((box) => { box.checked = checked })
    this.refresh()
  }

  get selectedCount() {
    return this.checkboxTargets.filter((box) => box.checked).length
  }
}
