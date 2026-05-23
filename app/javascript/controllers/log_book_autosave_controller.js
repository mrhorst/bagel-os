import { Controller } from "@hotwired/stimulus"

// Debounced autosave for the Log Book daily entry form. On any input/change,
// re-submit the form via fetch with an Accept header that asks the server for
// a turbo_stream payload — the inputs themselves aren't replaced so focus
// stays where the user left it.
//
// Safety net: every keystroke also writes the current form values to
// localStorage under a date-scoped key. If the network save fails we surface
// "Couldn't save — copy kept locally" so the user knows their work isn't lost.
// On successful save we clear the local copy.
export default class extends Controller {
  static values = {
    debounce: { type: Number, default: 700 },
    storageKey: String
  }

  connect() {
    this.timeoutId = null
    this.abortController = null
    this.restoreDraftNoticeIfAny()
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    this.abortController?.abort()
  }

  queue() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    this.backupDraft()
    this.markSaving()
    this.timeoutId = window.setTimeout(() => this.save(), this.debounceValue)
  }

  async save() {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const form = this.element
    const formData = new FormData(form)
    const token = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(form.action, {
        method: "PATCH",
        body: formData,
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token || ""
        },
        signal: this.abortController.signal,
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`save failed: ${response.status}`)

      const html = await response.text()
      window.Turbo?.renderStreamMessage(html)
      this.clearDraft()
    } catch (error) {
      if (error.name === "AbortError") return
      this.markError()
    }
  }

  backupDraft() {
    if (!this.hasStorageKeyValue) return
    try {
      const snapshot = {}
      new FormData(this.element).forEach((value, key) => { snapshot[key] = value })
      window.localStorage.setItem(this.storageKeyValue, JSON.stringify({
        savedAt: new Date().toISOString(),
        values: snapshot
      }))
    } catch (_) { /* quota or private mode — best effort */ }
  }

  clearDraft() {
    if (!this.hasStorageKeyValue) return
    try { window.localStorage.removeItem(this.storageKeyValue) } catch (_) {}
  }

  // If a prior session crashed mid-save, the local draft sticks around.
  // Surface it so the user knows we kept a copy even if the server didn't.
  restoreDraftNoticeIfAny() {
    if (!this.hasStorageKeyValue) return
    let raw
    try { raw = window.localStorage.getItem(this.storageKeyValue) } catch (_) { return }
    if (!raw) return
    const status = document.getElementById("log_book_save_status")
    if (status) {
      status.textContent = "Unsaved draft kept in this browser — start typing to retry"
      status.className = "log-book-save-status log-book-save-status-error"
    }
  }

  markSaving() {
    const status = document.getElementById("log_book_save_status")
    if (status) {
      status.textContent = "Saving…"
      status.className = "log-book-save-status"
    }
  }

  markError() {
    const status = document.getElementById("log_book_save_status")
    if (status) {
      status.textContent = "Couldn't save — copy kept in this browser"
      status.className = "log-book-save-status log-book-save-status-error"
    }
  }
}
