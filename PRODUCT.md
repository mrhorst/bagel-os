# Product

## Register

product

## Users

Bagel OS serves two distinct people inside one restaurant, on one shared internal tool (no per-user auth in the MVP — staff pick who they are via "Completing As"):

- **Operators / owners / managers.** They run inventory, purchasing, price intelligence, and order-guide work. Often at a desk or on a phone between other jobs, scanning numbers they need to trust before placing an order or settling a count. Analytical, time-pressed, allergic to wrong figures.
- **Back-of-house floor staff.** They complete the day's operational tasks — opening/closing checklists, cleaning, recurring and monthly work — on a shared device, hands full, mid-shift. Frequently non-technical. They need to see what's due, do it, prove it (a photo, a note), and move on.

The job to be done: **give a small restaurant team one trustworthy place to run inventory, purchasing, and daily operating work** — without spreadsheets, without guessing, without a steep learning curve.

## Product Purpose

Bagel OS is a **Restaurant Operations OS**: one application that connects inventory, purchasing, order guides, price intelligence, and staff task execution — with room for more operating workflows over time. It is the generic, multi-tenant product source, not one restaurant's install.

Two sibling modules share one app shell:

- **Inventory Module** — inventory counts, order guides, receipt imports, purchasing history, par-based shopping lists, and price intelligence. Every derived value (a normalized product, a price observation, a guide row) stays traceable back to the raw receipt line or order-guide line that produced it.
- **Tasks Module** — staff task lists, recurring and monthly work, completion history, and photo/note evidence of work done.

Success looks like: operators trust the numbers enough to act on them, staff actually complete and record their work, and nothing in the tool ever invents certainty it doesn't have. When units, package sizes, conversions, or product matches are ambiguous, the product surfaces a review instead of guessing.

## Brand Personality

**Warm, dependable, clear.** Bagel OS is a friendly, approachable operating tool — it speaks like a helpful colleague, not a corporate dashboard and not a cutesy consumer app. The voice is plain, reassuring, and human, written for someone who is busy and not necessarily technical.

The personality holds a deliberate tension: the product carries serious operational precision (data-first, accurate, trustworthy) but **delivers it warmly and plainly** so floor staff feel at ease and operators feel in control. Warmth is carried by tone of voice, the warm-paper surfaces, generous spacing and touch targets, and forgiving flows — **never** by decoration, gamification, or whimsy. Approachable, never childish. Confident, never cold.

## Anti-references

This should **not** look or feel like:

- **Generic SaaS / Linear-clone dashboards.** No cookie-cutter dark-SaaS template, no big-number-with-gradient hero-metric cliché, no endless grid of identical icon-heading-text cards. Avoid the "every B2B tool in 2026" look.
- **Legacy enterprise ERP.** No cluttered, gray, dated back-office software — no beveled buttons, tiny-everything density, dense chrome, or 2008-era inventory-system feel.
- **Playful consumer apps.** No cute mascots, gamification, emoji-as-UI, bouncy/elastic motion, or toy-like styling. "Friendly" is achieved through clarity and warmth, not whimsy. This is a professional tool people run a business on.

## Design Principles

1. **Correct numbers over flash.** Trust is the product. Accuracy, legibility, and traceability come before any visual flourish; if a flourish competes with clarity, the flourish loses.
2. **Traceable by design.** Every derived figure links back to the raw receipt or order-guide line it came from. Never hide provenance; let people drill from a number to its source.
3. **Don't guess — surface a review.** When units, conversions, package sizes, or product matches are uncertain, the interface flags it for human review rather than presenting a fabricated value as fact.
4. **Built for the floor.** Fast, legible, and forgiving for non-technical staff on shared devices, mid-shift, hands full. Plain language, large touch targets, no dead ends, easy undo.
5. **One OS, many modules.** Inventory and Tasks (and whatever comes next) are rooms in one coherent house — one shell, one design language — not a bag of separate apps stitched together.

## Accessibility & Inclusion

Target **WCAG 2.1 AA**:

- Body text ≥ 4.5:1 contrast; large text (≥18px, or bold ≥14px) ≥ 3:1. Placeholder and "muted" text must still clear 4.5:1 — no light-gray-for-elegance.
- Full keyboard operability with visible focus states on every interactive element.
- Every animation has a `prefers-reduced-motion: reduce` alternative (already wired in the design system: press states, view transitions, and reveals all degrade gracefully).
- Status and row state are never communicated by color alone (the system uses a 2px left rule + label, not a painted background).

Practical usage context to keep in mind even though it isn't a formal requirement: the Tasks module is used on small, sometimes older mobile devices in a back-of-house environment, so real-world legibility and comfortable touch targets matter in practice, not just on paper.
