import { Controller } from "@hotwired/stimulus"

// Debounced autosave for the Log Book daily entry form. On any input/change,
// re-submit the form via fetch with an Accept header that asks the server for
// a turbo_stream payload — that way the inputs themselves aren't replaced and
// the user's focus stays where they left it.
export default class extends Controller {
  static values = { debounce: { type: Number, default: 700 } }
  static targets = ["status"]

  connect() {
    this.timeoutId = null
    this.abortController = null
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    this.abortController?.abort()
  }

  queue() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
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

      const html = await response.text()
      window.Turbo?.renderStreamMessage(html)
    } catch (error) {
      if (error.name === "AbortError") return
      this.markError()
    }
  }

  markSaving() {
    const status = document.getElementById("log_book_save_status")
    if (status) status.textContent = "Saving…"
  }

  markError() {
    const status = document.getElementById("log_book_save_status")
    if (status) status.textContent = "Couldn't save — try again"
  }
}
