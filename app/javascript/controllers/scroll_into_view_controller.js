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
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ block: "center", behavior: "auto" })
  }
}
