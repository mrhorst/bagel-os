# Tasks Work Surface and Settings Stay Two Trees

The Tasks module will keep its **work surface** (`/tasks`: dashboard, focused list, occurrence detail — used during a shift) and its **settings** (`/tasks/manage`: settings hub, task-lists management, tasks management — used between shifts) as two separate route trees. Cross-tree actions that originate on the work surface (e.g. "Edit list") will resolve their back target to their origin rather than the trees being merged.

## Context

The two trees match two distinct jobs. During a shift, staff want a tight, read-mostly surface with no editing chrome. Between shifts, a manager configures lists and tasks. They differ in audience, frequency, and risk, and the URL split (`/tasks` vs `/tasks/manage`) keeps each surface focused.

The split leaks where a work-surface action dives into the settings tree. "Edit list" on the focused list view (`/tasks/lists/:id`) linked into `/tasks/manage/lists`, whose back arrow is hard-coded to "Settings". A user who came from their Prep list, edited it, and pressed back landed on the Tasks Settings hub — not the list they came from. The `_subpage_header` contract is that the back arrow must reach the destination its label names; a static `back_path` can't honor that when a page has two entry points from two trees.

This is the same class of problem already solved for occurrence detail, which can be reached from the dashboard, history, or a focused list. `Tasks::OccurrencesController#resolve_back_target` decides `back_path` and `back_label` together server-side so the arrow always agrees with its label and returns the user to where they actually came from.

## Decision

Keep the two trees. Generalize the `resolve_back_target` pattern to any cross-tree action instead of merging the trees. For list editing, the work-surface "Edit list" link carries an `origin=list` param; the controller resolves the back target (and the post-save redirect, and the Cancel link) to the focused list when that origin is present, and to the Task lists index otherwise. Both entry points now show a label-honest back arrow that returns to its true origin.

### Trade-offs considered

- **Keep separate, resolve back targets per origin (chosen).** Low risk, localized to the edit flow, preserves the during-shift vs between-shift separation, and reuses an established pattern. Cost: each cross-tree action must pass and resolve an origin; forgetting to is the failure mode this bug was an instance of.
- **Unify into one tree.** Removes the cross-tree seam entirely, so back targets follow naturally from hierarchy. But it collapses two audiences and risk profiles onto one surface, reintroduces editing chrome into the during-shift view, and is a broad, risky restructure of routes, controllers, and views for a problem that a focused fix solves.

## Consequences

New cross-tree actions from the work surface must follow the same convention: pass an explicit origin and resolve `back_path`/`back_label` (and any redirect) together server-side. Reviewers should treat a static `back_path` on a page with more than one entry point as a smell. If cross-tree origin plumbing proliferates, that is the signal to revisit unification — but until then the two-tree model stays, with its seams made honest rather than removed.
