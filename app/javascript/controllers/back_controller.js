import { Controller } from "@hotwired/stimulus"

// Click-to-go-back. If there is browser history within the same origin, use it;
// otherwise fall through to the link's href as a fallback destination.
export default class extends Controller {
  go(event) {
    const sameOriginReferrer = document.referrer && new URL(document.referrer).origin === window.location.origin
    if (sameOriginReferrer && window.history.length > 1) {
      event.preventDefault()
      window.history.back()
    }
  }
}
