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
  static targets = ["recovery"]
  static values = {
    debounce: { type: Number, default: 700 },
    storageKey: String
  }

  connect() {
    this.timeoutId = null
    this.abortController = null
    // True while an unsaved draft from a prior failed save is present but not
    // yet restored. While set, keystrokes must NOT overwrite that kept draft —
    // otherwise the first keypress (the old "start typing to retry") destroys
    // the only copy of the user's work before it can be recovered.
    this.pendingDraft = false
    this.detectPendingDraft()
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    this.abortController?.abort()
  }

  queue() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    // Don't clobber an un-restored kept draft. The user can still type and
    // save; a successful save (or an explicit Restore) is what releases it.
    if (!this.pendingDraft) this.backupDraft()
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
      // The work is now safe on the server, so the local copy can go and any
      // pending-draft recovery state is resolved.
      this.clearDraft()
      this.pendingDraft = false
      this.hideRecovery()
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

  // If a prior save failed, the local draft sticks around. Surface a Restore
  // control so the kept copy is actually recoverable — and mark the draft as
  // pending so keystrokes won't overwrite it before the user can pull it back.
  detectPendingDraft() {
    if (!this.readDraft()) return

    this.pendingDraft = true
    this.showRecovery()
    const status = document.getElementById("log_book_save_status")
    if (status) {
      status.textContent = "Unsaved draft kept in this browser — restore it below"
      status.className = "log-book-save-status log-book-save-status-error"
    }
  }

  // Pull the kept draft back into the form on demand. Never applied
  // automatically: a silent restore could clobber a newer entry saved from
  // another device, which is why the kept copy is offered, not forced.
  restoreDraft() {
    const draft = this.readDraft()
    if (!draft) return

    Object.entries(draft.values || {}).forEach(([name, value]) => {
      const field = this.element.elements.namedItem(name)
      if (!field || typeof field.length === "number") return // skip repeated-name groups
      if (field.type === "checkbox" || field.type === "radio") {
        field.checked = true
      } else {
        field.value = value
      }
    })

    // The form now holds the restored work, so normal autosave can resume and a
    // save attempt persists it.
    this.pendingDraft = false
    this.hideRecovery()
    this.queue()
  }

  readDraft() {
    if (!this.hasStorageKeyValue) return null
    let raw
    try { raw = window.localStorage.getItem(this.storageKeyValue) } catch (_) { return null }
    if (!raw) return null
    try { return JSON.parse(raw) } catch (_) { return null }
  }

  showRecovery() {
    if (this.hasRecoveryTarget) this.recoveryTarget.hidden = false
  }

  hideRecovery() {
    if (this.hasRecoveryTarget) this.recoveryTarget.hidden = true
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
