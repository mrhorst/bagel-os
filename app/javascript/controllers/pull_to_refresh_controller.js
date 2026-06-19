import { Controller } from "@hotwired/stimulus"

// Pull-to-refresh for touch devices.
//
// The app runs as a standalone PWA where iOS gives you no native
// pull-to-refresh, and the body sets `overscroll-behavior-y: none` to kill the
// rubber-band. This re-introduces a deliberate pull gesture at the top of the
// page: drag down past the threshold and release to reload the current screen
// through Turbo (falling back to a full reload).
//
// A floating chip slides down from the top while you pull and spins while the
// fresh page is being fetched. It is enabled only on coarse-pointer devices so
// desktop trackpads/mice never see it.
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 72 }, // px of resisted pull to arm
    max: { type: Number, default: 120 } // px the resisted pull is capped at
  }

  connect() {
    if (!window.matchMedia("(hover: none) and (pointer: coarse)").matches) return

    this.startY = 0
    this.startX = 0
    this.distance = 0
    this.tracking = false
    this.engaged = false
    this.armed = false
    this.refreshing = false

    this.indicator = this.#buildIndicator()
    this.spinner = this.indicator.querySelector(".ptr-spinner")

    this.onTouchStart = this.#onTouchStart.bind(this)
    this.onTouchMove = this.#onTouchMove.bind(this)
    this.onTouchEnd = this.#onTouchEnd.bind(this)

    window.addEventListener("touchstart", this.onTouchStart, { passive: true })
    window.addEventListener("touchmove", this.onTouchMove, { passive: false })
    window.addEventListener("touchend", this.onTouchEnd, { passive: true })
    window.addEventListener("touchcancel", this.onTouchEnd, { passive: true })
  }

  disconnect() {
    window.removeEventListener("touchstart", this.onTouchStart)
    window.removeEventListener("touchmove", this.onTouchMove)
    window.removeEventListener("touchend", this.onTouchEnd)
    window.removeEventListener("touchcancel", this.onTouchEnd)
    this.indicator?.remove()
  }

  #onTouchStart(event) {
    if (this.refreshing || event.touches.length !== 1) return
    // Only consider a pull when the page itself is scrolled to the very top and
    // the finger didn't land inside a nested scroller that's mid-scroll.
    if (this.#scrollTop() > 0 || this.#innerScrolled(event.target)) return

    this.startY = event.touches[0].clientY
    this.startX = event.touches[0].clientX
    this.tracking = true
    this.engaged = false
    this.distance = 0
  }

  #onTouchMove(event) {
    if (!this.tracking || this.refreshing) return

    const deltaY = event.touches[0].clientY - this.startY
    const deltaX = event.touches[0].clientX - this.startX

    // Pulling up, or the page got scrolled away from the top — abandon.
    if (deltaY <= 0 || this.#scrollTop() > 0) {
      if (this.distance > 0) this.#reset()
      this.tracking = false
      return
    }

    // Wait until the gesture clearly reads as a downward pull before claiming
    // it — a mostly-horizontal swipe belongs to a carousel, not to us.
    if (!this.engaged) {
      if (deltaY < 8) return
      if (deltaY <= Math.abs(deltaX)) {
        this.tracking = false
        return
      }
      this.engaged = true
    }

    // We own this gesture now: stop the page from scrolling/bouncing.
    event.preventDefault()

    // Rubber-band resistance — the further you pull, the harder it gets.
    this.distance = Math.min(deltaY * 0.5, this.maxValue)
    this.#render(this.distance)
  }

  #onTouchEnd() {
    if (!this.tracking || this.refreshing) return
    this.tracking = false

    if (this.distance >= this.thresholdValue) {
      this.#refresh()
    } else {
      this.#reset()
    }
  }

  #render(distance) {
    const ratio = Math.min(distance / this.thresholdValue, 1)
    const offset = -48 + ratio * 108 // hidden above (-48px) → resting (60px)

    this.indicator.classList.remove("is-animating")
    this.indicator.style.transform = `translateY(${offset}px)`
    this.indicator.style.opacity = `${ratio}`
    this.spinner.style.transform = `rotate(${ratio * 270}deg)`

    const armed = distance >= this.thresholdValue
    if (armed !== this.armed) {
      this.armed = armed
      this.indicator.classList.toggle("is-armed", armed)
    }
  }

  #refresh() {
    this.refreshing = true
    this.armed = false
    this.indicator.classList.add("is-animating", "is-refreshing")
    this.indicator.classList.remove("is-armed")
    this.indicator.style.transform = "translateY(60px)"
    this.indicator.style.opacity = "1"
    this.spinner.style.transform = "" // hand rotation off to the CSS keyframes

    // Drop any cached snapshot so the user sees fresh server data, then revisit
    // the current URL. The spinner keeps turning until Turbo swaps the body.
    if (window.Turbo) {
      window.Turbo.cache?.clear()
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }

  #reset() {
    this.armed = false
    this.distance = 0
    this.indicator.classList.add("is-animating")
    this.indicator.classList.remove("is-armed")
    this.indicator.style.transform = "translateY(-48px)"
    this.indicator.style.opacity = "0"
    this.spinner.style.transform = ""
  }

  #buildIndicator() {
    const el = document.createElement("div")
    el.className = "ptr"
    el.setAttribute("aria-hidden", "true")
    el.innerHTML = `
      <span class="ptr-spinner">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" aria-hidden="true">
          <path d="M20 12a8 8 0 1 1-2.34-5.66" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
          <path d="M20 4v5h-5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </span>
    `
    document.body.appendChild(el)
    return el
  }

  #scrollTop() {
    return window.scrollY || document.documentElement.scrollTop || 0
  }

  // True when the touch started inside a nested scrollable element that is not
  // at its own top — there the gesture means "scroll this", not "refresh".
  #innerScrolled(target) {
    let el = target
    while (el instanceof Element && el !== document.body) {
      if (el.scrollTop > 0) {
        const overflowY = window.getComputedStyle(el).overflowY
        if (overflowY === "auto" || overflowY === "scroll") return true
      }
      el = el.parentElement
    }
    return false
  }
}
