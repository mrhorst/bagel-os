import { Controller } from "@hotwired/stimulus"

// Save a file without navigating the installed PWA away from itself.
//
// An iOS home-screen PWA has no browser chrome, so a normal link to an
// attachment strands the user on a chrome-less page that can't even render the
// download. Instead we fetch the bytes and hand them to the native share sheet
// where it exists (iOS — the user picks "Save to Photos" / "Save to Files"),
// falling back to a regular download link on platforms without it.
//
// Drives the photo crop/original links (GET) and the multi-select ZIP export
// (POST of the checked photo_asset_ids). The export POST carries the page's
// global CSRF token via header, so it works regardless of which form the
// trigger lives in — a per-form token would 422 against the export endpoint.
export default class extends Controller {
  static values = {
    url: String,
    filename: String,
    method: { type: String, default: "get" },
    ids: String // selector for checkboxes posted as photo_asset_ids[]
  }

  async save(event) {
    event.preventDefault()
    if (this.busy) return

    const ids = this.selectedIds
    if (this.post && ids.length === 0) {
      window.alert("Select at least one photo to download.")
      return
    }

    this.busy = true
    this.element.setAttribute("aria-busy", "true")
    try {
      const blob = await this.fetchBlob(ids)
      await this.deliver(blob)
    } catch (error) {
      // A dismissed share sheet is not an error worth reporting.
      if (error.name !== "AbortError") {
        window.alert("Sorry — that download didn't work. Please try again.")
      }
    } finally {
      this.busy = false
      this.element.removeAttribute("aria-busy")
    }
  }

  async fetchBlob(ids) {
    const options = { method: this.post ? "POST" : "GET" }
    if (this.post) {
      const body = new FormData()
      ids.forEach((id) => body.append("photo_asset_ids[]", id))
      options.body = body
      options.headers = { "X-CSRF-Token": this.csrfToken }
    }
    const response = await fetch(this.url, options)
    if (!response.ok) throw new Error(`Download failed (${response.status})`)
    return response.blob()
  }

  async deliver(blob) {
    const file = new File([blob], this.filename, {
      type: blob.type || "application/octet-stream"
    })

    // iOS / Android: let the user choose where the file goes.
    if (navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ files: [file] })
        return
      } catch (error) {
        if (error.name === "AbortError") return // user dismissed the sheet
        // Anything else (e.g. share unavailable mid-flight): fall through to a
        // direct download rather than leaving the user with nothing.
      }
    }

    // Desktop and anything without a working share sheet: a plain download.
    const href = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = href
    link.download = this.filename
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(href)
  }

  get post() {
    return this.methodValue.toLowerCase() === "post"
  }

  // Prefer an explicit url value; otherwise use the link's own href.
  get url() {
    return this.urlValue || this.element.getAttribute("href") || ""
  }

  get filename() {
    return this.filenameValue || "download"
  }

  get selectedIds() {
    if (!this.hasIdsValue || this.idsValue === "") return []
    return Array.from(this.element.querySelectorAll(this.idsValue))
      .filter((box) => box.checked)
      .map((box) => box.value)
  }

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }
}
