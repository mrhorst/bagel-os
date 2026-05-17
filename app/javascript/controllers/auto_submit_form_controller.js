import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = { asyncFrame: String }

  connect() {
    this.timeoutId = null
    this.abortController = null
  }

  submit(event) {
    if (!this.hasAsyncFrameValue) return

    event.preventDefault()
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.element.action, window.location.origin)
    url.search = new URLSearchParams(new FormData(this.element)).toString()
    this.element.setAttribute("aria-busy", "true")

    fetch(url, {
      headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Request failed with ${response.status}`)
        return response.text()
      })
      .then((html) => {
        const documentFragment = new DOMParser().parseFromString(html, "text/html")
        const currentFrames = document.querySelectorAll(`[data-async-frame="${this.asyncFrameValue}"]`)
        const newFrames = documentFragment.querySelectorAll(`[data-async-frame="${this.asyncFrameValue}"]`)

        currentFrames.forEach((frame, index) => {
          const replacement = newFrames[index]
          if (replacement) frame.replaceWith(replacement)
        })

        window.history.replaceState({}, "", url.toString())
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.element.submit()
      })
      .finally(() => {
        this.element.removeAttribute("aria-busy")
      })
  }

  queueSearch() {
    this.queueSubmit(300)
  }

  queueChange() {
    this.queueSubmit(0)
  }

  queueSubmit(delay) {
    window.clearTimeout(this.timeoutId)
    this.timeoutId = window.setTimeout(() => {
      if (this.element.requestSubmit) {
        this.element.requestSubmit(this.submitTarget)
      } else {
        this.element.submit()
      }
    }, delay)
  }
}
