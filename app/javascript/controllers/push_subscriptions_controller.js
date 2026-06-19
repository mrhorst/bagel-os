import { Controller } from "@hotwired/stimulus"

// Web Push opt-in toggle.
//
// Bridges the browser's PushManager and our PushSubscription rows. On connect
// it reflects the current state on the button; tapping it subscribes (asking
// permission first) or unsubscribes. The VAPID public key arrives as a value;
// the CSRF token is read from the meta tag for the fetch.
//
//   data-controller="push-subscriptions"
//   data-push-subscriptions-public-key-value="<%= WebPushConfig.public_key %>"
//   <button data-push-subscriptions-target="button"
//           data-action="push-subscriptions#toggle">…</button>
export default class extends Controller {
  static values = { publicKey: String }
  static targets = ["button"]

  async connect() {
    if (!this.supported) return this.render("unsupported")
    if (Notification.permission === "denied") return this.render("denied")

    const subscription = await this.currentSubscription()
    this.render(subscription ? "subscribed" : "unsubscribed")
  }

  get supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  async toggle() {
    const subscription = await this.currentSubscription()
    if (subscription) {
      await this.unsubscribe(subscription)
    } else {
      await this.subscribe()
    }
  }

  async subscribe() {
    this.render("working")

    const permission = await Notification.requestPermission()
    if (permission !== "granted") return this.render("denied")

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.decodeKey(this.publicKeyValue)
    })

    const saved = await this.send("/push-subscriptions", "POST", {
      push_subscription: this.serialize(subscription)
    })

    if (saved) {
      this.render("subscribed")
    } else {
      // Don't leave a browser subscription we failed to record server-side.
      await subscription.unsubscribe()
      this.render("error")
    }
  }

  async unsubscribe(subscription) {
    this.render("working")
    await this.send("/push-subscriptions", "DELETE", { endpoint: subscription.endpoint })
    await subscription.unsubscribe()
    this.render("unsubscribed")
  }

  async currentSubscription() {
    const registration = await navigator.serviceWorker.ready
    return registration.pushManager.getSubscription()
  }

  serialize(subscription) {
    const keys = subscription.toJSON().keys
    return { endpoint: subscription.endpoint, p256dh_key: keys.p256dh, auth_key: keys.auth }
  }

  async send(url, method, body) {
    try {
      const response = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
        body: JSON.stringify(body)
      })
      return response.ok
    } catch (_error) {
      return false
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content
  }

  render(state) {
    if (!this.hasButtonTarget) return

    const labels = {
      unsupported: "Notifications aren’t supported on this device",
      denied: "Notifications are blocked — enable them in your browser settings",
      unsubscribed: "Enable notifications",
      working: "Working…",
      subscribed: "Disable notifications",
      error: "Couldn’t enable notifications — try again"
    }

    this.buttonTarget.textContent = labels[state] ?? labels.unsubscribed
    this.buttonTarget.disabled = ["unsupported", "denied", "working"].includes(state)
    this.element.dataset.pushState = state
  }

  // VAPID public keys are URL-safe base64; PushManager wants raw bytes.
  decodeKey(base64) {
    const padding = "=".repeat((4 - (base64.length % 4)) % 4)
    const normalized = (base64 + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = atob(normalized)
    return Uint8Array.from([...raw].map((char) => char.charCodeAt(0)))
  }
}
