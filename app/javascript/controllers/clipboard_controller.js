import { Controller } from "@hotwired/stimulus"

// One-tap "Copy" for a value shown in a readonly field — the share link.
//
// The share panel exists to hand a public link to someone outside the app (a
// designer, a printer), so copying that link is the primary action once it's
// been minted. A readonly text field the user has to select and copy by hand
// buries that action — fiddly on a phone, where the field is the primary
// surface and a readonly input won't even raise the keyboard. This gives a real
// Copy button that puts the link on the clipboard in one tap and confirms it
// did, so the affordance matches the intent.
//
// Two copy paths, so the button never silently does nothing: the async
// Clipboard API where it's available (a secure context — https and the
// installed PWA both qualify), falling back to selecting the field and
// document.execCommand("copy"), which needs no permission and works in older
// browsers. The visible confirmation fires regardless of which path ran.
export default class extends Controller {
  static targets = ["source", "button", "status"]
  static values = { restoreAfter: { type: Number, default: 1600 } }

  copy() {
    const text = this.hasSourceTarget ? this.sourceTarget.value : ""
    this.write(text).then((ok) => this.confirm(ok))
  }

  async write(text) {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(text)
        return true
      }
    } catch (_error) {
      // Blocked (no permission / not focused): fall through to the legacy path.
    }
    try {
      if (this.hasSourceTarget) {
        this.sourceTarget.focus()
        this.sourceTarget.select()
        return document.execCommand("copy")
      }
    } catch (_error) {
      // Nothing left to try.
    }
    return false
  }

  confirm(ok) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ok
        ? "Link copied to clipboard."
        : "Couldn't copy automatically — the link is selected, press ⌘/Ctrl+C."
    }
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    if (this._original === undefined) this._original = button.textContent
    if (this._resetTimer) clearTimeout(this._resetTimer)

    button.textContent = ok ? "Copied!" : "Press ⌘/Ctrl+C"
    if (ok) button.classList.add("button-success") // reuse the success token, not accent
    this._resetTimer = setTimeout(() => {
      button.textContent = this._original
      button.classList.remove("button-success")
      if (this.hasStatusTarget) this.statusTarget.textContent = ""
    }, this.restoreAfterValue)
  }
}
