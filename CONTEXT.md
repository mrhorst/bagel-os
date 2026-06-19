# Restaurant Operations OS Context

Restaurant Operations OS is a single application for restaurant operators who need one place to connect inventory, purchasing, staff task execution, and future operating workflows.

## Language

**Restaurant Operations OS**:
The overall product for running restaurant operating workflows in one place.
_Avoid_: separate apps, microservices, plugin platform

**Module**:
A bounded workflow area inside Restaurant Operations OS.
_Avoid_: separate app, service, engine

**Inventory Module**:
The module for inventory counts, order guides, receipt imports, purchasing history, and price intelligence.
_Avoid_: whole app

**Tasks Module**:
The module for staff task lists, recurring work, completion history, and task evidence.
_Avoid_: schedule, shift planner, timeclock

**Marketing Module**:
The shared library for collecting, tagging, and exporting marketing photo assets (food and product photos).
_Avoid_: social media scheduler, digital asset management platform

**Photo Asset**:
One photo collected for marketing use, carrying tags, a caption, and notes.
_Avoid_: photo evidence, task attachment

**Photo Asset Status**:
The tagging lifecycle of a photo asset: pending (untagged), needs review (AI suggestions awaiting a human), or tagged.
_Avoid_: approval workflow, publish state

**Photo Export**:
The one-command export of photo assets and their manifest for use outside the app.
_Avoid_: external API integration

**Marketing Tag**:
An admin-managed label in the marketing vocabulary, with a rule that tells the AI tagger when to apply it.
_Avoid_: free-form keyword, hashtag

**Photo Tagging**:
The link between a photo asset and a marketing tag, recording whether a human or the AI added it and whether it's confirmed.
_Avoid_: category column, enum

**AI Photo Tagging**:
The automated first pass that suggests tags from the vocabulary for a photo, always confirmed by staff before they count.
_Avoid_: final say, auto-publish

**Staff Member**:
A person credited with completing restaurant operating work.
_Avoid_: user, login, employee record

**Inactive Staff Member**:
A staff member kept in history but unavailable for new task completion.
_Avoid_: deleted staff member

**Staff Attribution**:
The operational record of which staff member is credited with doing a piece of work.
_Avoid_: authentication, identity proof

**Completing As**:
The currently selected staff member credited for task completions on a staff device or browser session.
_Avoid_: logged in as

**Task Completion**:
The record that one task occurrence was completed by one credited staff member.
_Avoid_: repeated check-in

**Completion Undo**:
The deliberate reversal of a task completion after confirmation.
_Avoid_: silent edit, photo replacement

**Undone Completion**:
A task completion that was reversed but kept as historical evidence.
_Avoid_: deleted completion

**Undo Note**:
An optional note explaining why a task completion was undone.
_Avoid_: required correction reason

**Photo Evidence**:
The single image attached at completion time to prove a task occurrence was performed.
_Avoid_: optional task photo, after-the-fact upload, multiple photos

**Completion Note**:
An optional note recorded when a task occurrence is completed.
_Avoid_: task instruction, setup note

**Task Setup**:
The workflow for creating and maintaining task lists and task definitions.
_Avoid_: permission system, manager-only security

**Archived Task**:
A task removed from future staff work while preserving its historical occurrences.
_Avoid_: deleted task

**Archived Task List**:
A task list removed from future staff work while preserving historical occurrences for its tasks.
_Avoid_: deleted task list

**Task**:
A unit of restaurant operating work that staff are expected to complete.
_Avoid_: todo, checklist item

**Task Instruction**:
Plain text guidance attached to a task.
_Avoid_: rich text, nested checklist, SOP attachment

**Task List**:
A named operating group of related tasks.
_Avoid_: checklist, folder, hard-coded category

**Task Order**:
The manual display order for task lists and tasks inside a list.
_Avoid_: drag-and-drop requirement

**Task Occurrence**:
The dated instance of a task that staff complete or miss.
_Avoid_: generated checklist row, inferred history

**One-Time Task**:
A task expected once that remains late until completed.
_Avoid_: missed one-time task

**Task Snapshot**:
The task title, instruction, list name, and evidence requirement copied onto a task occurrence.
_Avoid_: live lookup for history

**Monthly Task**:
A task expected once during a local calendar month.
_Avoid_: specific day-of-month task

**This Month Section**:
The staff-facing area that shows open monthly task occurrences.
_Avoid_: task list, module

**Task History**:
The historical view of task occurrences and completions.
_Avoid_: audit log, report export

**Due At**:
The date and time by which a task occurrence must be completed.
_Avoid_: date-only due date

**Late Task**:
A task occurrence whose due time has passed but can still be completed.
_Avoid_: missed task

**Missed Task**:
A recurring task occurrence whose completion window closed without completion.
_Avoid_: late task

**Operating Day**:
The local calendar day used to decide when daily and weekly task occurrences become missed.
_Avoid_: shift, business hours

## Relationships

- **Restaurant Operations OS** contains one or more **Modules**.
- The **Inventory Module** and **Tasks Module** are sibling **Modules** inside the same application.
- A **Module** is not a separately deployed application.
- The **Tasks Module** uses **Staff Attribution** to record which **Staff Member** completed work.
- An **Inactive Staff Member** remains visible in history but cannot be selected for new completions.
- **Completing As** supplies the **Staff Member** for new **Task Completions**.
- **Completing As** can persist in the local browser session until changed.
- **Task Setup** is part of the **Tasks Module** but is not permission-protected in the MVP.
- A **Task List** is a freely named operating group.
- A **Task List** contains one or more **Tasks**.
- An **Archived Task List** archives its active **Tasks**.
- A **Task** belongs to exactly one **Task List**.
- **Task Order** controls how lists and tasks are displayed to staff.
- A **Task** may have one plain-text **Task Instruction**.
- A **Task** is not assigned to an individual **Staff Member** in the MVP.
- An **Archived Task** stops producing future work but keeps completed and missed history.
- Archiving a **Task** removes open, uncompleted work for the current and future days.
- A **One-Time Task** rolls forward as a **Late Task** until completed.
- A recurring **Task** produces one **Task Occurrence** for each date it is due.
- A **Task Occurrence** stores a **Task Snapshot**.
- A **Task Occurrence** is the historical anchor for completion, missed status, and evidence.
- A **Task Occurrence** has at most one active **Task Completion**.
- A **Task Completion** can be undone only through **Completion Undo** with confirmation.
- **Completion Undo** is allowed only during the same **Operating Day** as the occurrence.
- **Completion Undo** preserves the old **Task Completion** and **Photo Evidence** as an **Undone Completion**.
- **Completion Undo** may include one optional **Undo Note**.
- After **Completion Undo**, the **Task Occurrence** can be completed again during the same **Operating Day**.
- **Undone Completion** details are visible from the task occurrence detail view, not the main history list.
- A **Task Completion** may require one **Photo Evidence** image.
- Required **Photo Evidence** must be attached when the **Task Completion** is created.
- A **Task Completion** may include one optional **Completion Note**.
- A **Task Occurrence** has one **Due At** value.
- For the MVP, a **Task** creates at most one **Task Occurrence** per **Operating Day**.
- A **Monthly Task** creates one **Task Occurrence** for the calendar month.
- A **Monthly Task** becomes missed when the next local calendar month begins.
- The **This Month Section** shows open **Monthly Tasks** separately from today's time-specific work.
- A **Monthly Task** still belongs to a normal **Task List**.
- **Task History** defaults to the last seven local calendar days.
- A **Late Task** can still be completed.
- A **Missed Task** cannot be completed after its completion window closes.
- For the MVP, the **Operating Day** closes at local calendar midnight.

## Example dialogue

> **Dev:** "Should the **Tasks Module** be a separate app from the **Inventory Module**?"
> **Domain expert:** "No. They are separate workflow areas inside **Restaurant Operations OS**, sharing the same application shell."
>
> **Dev:** "Does **Staff Attribution** mean the app proves who was logged in?"
> **Domain expert:** "No. For the MVP, staff select the **Staff Member** credited with the work; authentication can come later."
>
> **Dev:** "Does **Completing As** mean someone is authenticated?"
> **Domain expert:** "No. It is only the selected **Staff Member** used for task attribution on that device or browser session."
>
> **Dev:** "Can **Completing As** stay selected after refresh?"
> **Domain expert:** "Yes. It can persist locally for convenience as long as it stays visible and easy to change."
>
> **Dev:** "Do inactive staff disappear from history?"
> **Domain expert:** "No. An **Inactive Staff Member** stays in history but is not available for new completions."
>
> **Dev:** "Should **Task Setup** be manager-only right away?"
> **Domain expert:** "No. The MVP can expose setup screens inside the internal app; manager permissions come later with authentication."
>
> **Dev:** "Should we call these checklist items or todos?"
> **Domain expert:** "No. Use **Task** for the work item and **Task List** for the group staff work through."
>
> **Dev:** "Are **Task Lists** fixed types like Opening, Closing, or Cleaning?"
> **Domain expert:** "No. They are freely named operating groups."
>
> **Dev:** "Can one **Task** appear in multiple **Task Lists**?"
> **Domain expert:** "No. A **Task** belongs to exactly one **Task List** in the MVP."
>
> **Dev:** "Do we need drag-and-drop to order tasks?"
> **Domain expert:** "No. The MVP only needs simple **Task Order** fields."
>
> **Dev:** "Are **Task Instructions** rich text or nested steps?"
> **Domain expert:** "No. The MVP uses plain text instructions only."
>
> **Dev:** "Do we assign **Tasks** to individual **Staff Members**?"
> **Domain expert:** "No. The MVP keeps tasks shared and records who completed them through **Staff Attribution**."
>
> **Dev:** "Should removing a **Task** delete its history?"
> **Domain expert:** "No. Archive the **Task** so future work stops but historical occurrences remain."
>
> **Dev:** "Does archiving an open **Task** make today's occurrence missed later?"
> **Domain expert:** "No. Archiving removes open work; only completed and missed historical occurrences stay."
>
> **Dev:** "What happens to **Tasks** when their **Task List** is archived?"
> **Domain expert:** "They are archived too, while completed and missed history remains."
>
> **Dev:** "Can we infer old history from today's recurrence rule?"
> **Domain expert:** "No. Each due date should have a **Task Occurrence** so history stays true even when the **Task** changes later."
>
> **Dev:** "Does editing a **Task** rewrite old history?"
> **Domain expert:** "No. Completed and missed occurrences keep their **Task Snapshot**; open future work can reflect the edited **Task**."
>
> **Dev:** "Can the same **Task Occurrence** be completed more than once?"
> **Domain expert:** "No. If work needs to happen twice, create separate **Task Occurrences**."
>
> **Dev:** "Can staff undo an accidental **Task Completion**?"
> **Domain expert:** "Yes, but only through a confirmed **Completion Undo** action."
>
> **Dev:** "Does **Completion Undo** delete the old photo?"
> **Domain expert:** "No. Keep the old **Photo Evidence** with the **Undone Completion**."
>
> **Dev:** "Should **Undone Completions** clutter the main history list?"
> **Domain expert:** "No. Show them from the occurrence detail view."
>
> **Dev:** "Does undo require a reason?"
> **Domain expert:** "No. An **Undo Note** is optional."
>
> **Dev:** "Can a task be completed again after undo?"
> **Domain expert:** "Yes, if it is still the same **Operating Day**."
>
> **Dev:** "Can staff undo yesterday's completion today?"
> **Domain expert:** "No. **Completion Undo** is only allowed during the same **Operating Day**."
>
> **Dev:** "Can staff add **Photo Evidence** after completing a task?"
> **Domain expert:** "No. If **Photo Evidence** is required, it must be attached at completion time."
>
> **Dev:** "Can a task completion have multiple photos?"
> **Domain expert:** "No. The MVP supports one **Photo Evidence** image per **Task Completion**."
>
> **Dev:** "Can staff explain something when completing a task?"
> **Domain expert:** "Yes. They can add an optional **Completion Note**."
>
> **Dev:** "How do we handle bathroom checks at 10 AM, 2 PM, and 6 PM?"
> **Domain expert:** "For the MVP, create three **Tasks**, each with its own **Due At** time."
>
> **Dev:** "Does a **Monthly Task** need a specific day of the month?"
> **Domain expert:** "No. Deep-cleaning style work can be done any time during that calendar month."
>
> **Dev:** "When does a **Monthly Task** become missed?"
> **Domain expert:** "At local midnight when the next calendar month begins."
>
> **Dev:** "Where should staff see **Monthly Tasks**?"
> **Domain expert:** "In a **This Month Section**, separate from today's time-specific work."
>
> **Dev:** "Does the **This Month Section** replace **Task Lists**?"
> **Domain expert:** "No. **Monthly Tasks** still belong to normal **Task Lists**; the section is only how staff see them."
>
> **Dev:** "What should **Task History** show first?"
> **Domain expert:** "Default to the last seven local calendar days."
>
> **Dev:** "Can staff complete yesterday's missed recurring task today?"
> **Domain expert:** "No. Once the operating day closes, the recurring occurrence is a **Missed Task** unless it was completed before then."
>
> **Dev:** "What happens to an unfinished **One-Time Task**?"
> **Domain expert:** "It rolls forward as a **Late Task** until completed."
>
> **Dev:** "When does the **Operating Day** close for now?"
> **Domain expert:** "Use local calendar midnight for the MVP."

## Product Domain

The app models:

- suppliers and vendor receipt imports
- receipts and receipt line items
- normalized products and raw product aliases
- price observations for historical price tracking
- order guide imports and guide rows
- inventory items and inventory counts
- review queues for uncertain parsing, matching, and unit normalization

## Core Principles

- Correct numbers matter more than flashy UI.
- Every imported value should be traceable to the raw receipt line or order guide line it came from.
- Do not guess units, package sizes, conversions, or product merges.
- Keep real restaurant data in `.private/` or a separate private data repo.
- Keep tracked code and docs generic enough to reuse across restaurants.

## Current Architecture

- Rails with Active Record and server-rendered views.
- SQLite for local development by default.
- No npm package surface.
- Vendor receipt parsing, order-guide parsing, matching, pricing, and reporting live under `app/services/purchasing/`.

## Future Direction

- Supplier-specific importer adapters.
- In-app approval screens for guide/product links.
- Recipe and menu item costing using `PriceObservation` as the pricing source of truth.
- Optional LLM assistant that answers through structured database queries, not raw CSV/PDF scraping.
