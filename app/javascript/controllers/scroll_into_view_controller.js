import { Controller } from "@hotwired/stimulus"

// When a nested recipe form (Add ingredient / inline edit / add substitute) is
// rejected, the controller re-renders the show page in place so the typed input
// and its error survive (see recipe_ingredients_controller). But those forms
// submit natively — with no place-preserving redirect fragment on the failure
// render, the browser lands at the page TOP. On a long recipe that strands the
// validation error below the fold, so a rejected submit reads as a silent no-op.
//
// Attach this to the errored form/row and it scrolls itself back into view on
// connect, mirroring the success path's place-preserving scroll, so the person
// actually sees the error they need to fix.
//
// The scroll is deferred to the next frame on purpose. A native-submit re-render
// (the recipe forms) is already settled by connect, but a Turbo-driven re-render
// (e.g. the product edit form) resets scroll to the page TOP in its own render
// pass, which runs AFTER Stimulus connect — so a connect-time scroll would be
// undone a beat later. requestAnimationFrame runs after that render pass, so the
// element wins the final scroll position in both cases.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      this.element.scrollIntoView({ block: "center", behavior: "auto" })
    })
  }
}
