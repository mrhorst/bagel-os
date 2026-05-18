# Tasks Module Implementation Prompt and Plan

This plan is for adding a 7tasks-style staff task system as a new module inside the existing Rails app. The first version should be useful for a real restaurant without turning Restaurant Operations OS into a generic platform too early.

## Copy-Paste Implementation Prompt

You are working in the `restaurant-inventory-os` Rails app. Build the first production-minded version of a Tasks module for restaurant staff.

The product direction is Restaurant Operations OS: one Rails app composed of bounded modules. The existing Inventory module handles inventory counts, order guides, purchasing, receipt imports, and price intelligence. The new Tasks module should live beside Inventory as its own bounded module, not replace or rewrite the existing inventory/purchasing code. A future Schedule module may exist later, but do not build scheduling, shifts, payroll, availability, or timeclock features now.

Core user story:

- A manager or trusted operator creates task lists such as Opening, Closing, Cleaning, Prep, Food Safety, or Weekly Deep Clean.
- A manager or trusted operator creates tasks inside those lists.
- Tasks can be one-time or recurring.
- Staff see the tasks due for today, grouped by list.
- A normal task can be marked complete with one clear action.
- A task can be configured to require photo evidence; those tasks cannot be completed until a photo is attached.
- The app must keep history so the restaurant can see what was done yesterday, last week, or last year, including who completed it and when.

Current app constraints:

- Rails with Active Record and server-rendered views.
- SQLite local development.
- No npm package surface. Do not add JavaScript package managers or frontend dependencies.
- Keep tracked code and docs generic enough to reuse across restaurants.
- Real restaurant names, real staff/customer data, vendor data, private photos, and install-specific notes must stay out of tracked files.
- Prefer simple Rails models, controllers, services, and integration tests.

Architecture direction:

- Treat Tasks as a Rails module using namespaced controllers and services under `Tasks::`.
- Treat a module as a bounded workflow area inside the app, not as a separately deployed app.
- Use Task and Task List as the canonical staff-facing language. Avoid todo as core terminology.
- Use `Task`/`tasks` for the reusable task definition model/table; do not rename it to avoid Rake terminology.
- Prefer model names that are clear in the restaurant domain:
  - `TaskList`
  - `Task`
  - `TaskOccurrence`
  - `TaskCompletion`
  - `StaffMember`
- Do not create a generic plugin architecture yet.
- Do not call the future scheduling module into existence. `StaffMember` is allowed only because task completion needs staff attribution.
- Do not rename app branding/UI from Inventory OS as part of the Tasks MVP. Broader Restaurant Operations OS language can live in domain docs first.
- Use staff attribution for the MVP, not authentication. Staff can select the staff member credited with the work; the app does not need to prove identity yet.
- Do not enforce manager permissions in v1. Task setup screens are internal setup workflows, not protected manager-only surfaces yet.
- Add simple staff setup inside the Tasks module so staff members can be created and deactivated without Rails console access.
- Enable Active Storage for task completion photos instead of adding an image-upload dependency. Photo-required tasks are in scope for v1.

Acceptance criteria for the first useful version:

- Navigation includes a Tasks module entry.
- `/tasks` shows today's due tasks grouped by active task list.
- Task setup supports creating, editing, archiving, and reordering task lists.
- Task setup supports creating, editing, and archiving tasks with title, instructions, list, recurrence, due time, active flag, and photo-required flag.
- Task lists and tasks use simple position-based ordering in v1; drag-and-drop is not required.
- Task instructions are plain text only in v1.
- Tasks are not assigned to individual staff members in v1.
- Tasks are scoped to the current app/install; do not add a Location model in v1.
- Do not integrate Tasks with Inventory models in v1. Tasks may mention inventory work in plain text only.
- Do not require main dashboard integration in v1; keep task metrics on `/tasks`.
- Staff can complete a due task using the board-level Completing As staff selection.
- Photo-required tasks reject completion unless exactly one photo is attached at completion time.
- Normal tasks do not accept optional photo evidence in v1.
- Completed tasks store completed-by, completed-at, notes, and photo evidence when present.
- Completion notes are optional for both normal and photo-required tasks.
- Each task occurrence can have only one active completion.
- Completed task occurrences can be undone with a confirmation step.
- Completion undo is allowed only during the same operating day.
- History can be filtered by date or date range and shows open, late, completed, or missed occurrences.
- Task history defaults to the last seven local calendar days.
- Editing a recurring task does not rewrite already completed history.
- Editing a task should update future/open work but must not rewrite completed or missed history.
- Archiving a task stops future work without deleting completed or missed history.
- Archiving a task removes open, uncompleted current/future occurrences so they do not later become missed.
- Archiving a task list archives its active tasks and preserves completed/missed history.
- Recurring tasks produce dated task occurrences. Do not infer historical work only from the current task definition.
- Due tasks use a date and time, not a date-only deadline.
- A task definition creates at most one occurrence per operating day in v1.
- If work must happen multiple times in one day, create separate tasks with separate due times for the MVP.
- One-time tasks roll forward as late until completed; they do not become missed at midnight.
- Rolled-forward one-time tasks remain visible on the staff board every day until completed or archived.
- Monthly tasks are supported in v1 as once-per-calendar-month work windows, not specific day-of-month appointments.
- Monthly tasks can be completed any time during the local calendar month and become missed when the next month begins.
- Monthly tasks stay open for the whole calendar month; do not introduce late or due-soon monthly status in v1.
- Open monthly tasks appear in a separate This Month section on the staff task board.
- Monthly tasks still belong to normal task lists; This Month is a view section, not a separate grouping model.
- A task occurrence can be completed late during the same operating day.
- Once a task occurrence becomes missed after its completion window closes, it cannot be completed after the fact.
- For v1, the operating day closes at local calendar midnight.
- Relevant model tests, service tests, and integration tests are added.
- Verification passes:
  - `bin/check-no-npm-surface`
  - `bin/rails test`
  - `bin/rubocop`
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

## Module Boundary

Implement this as a bounded module inside the monolithic Rails app:

- controllers: `app/controllers/tasks/...`
- views: `app/views/tasks/...`
- services: `app/services/tasks/...`
- models: top-level Active Record models with task-specific names
- tests: model, service, and integration tests focused on the task workflow

Do not build a separate engine, API-only app, JavaScript app, or multi-module registry yet. The Restaurant Operations OS direction can be supported by clean navigation and namespacing first.

## Recommended Data Model

### StaffMember

Represents a person who can be credited with completing tasks. This is not an authentication system.

Suggested fields:

- `display_name`
- `active`
- `notes`

Rules:

- Require `display_name`.
- Keep seeded/test staff generic, such as `Demo Manager` and `Demo Staff`.
- Real staff names are install data in the database, not tracked source.
- Staff selection records operational attribution, not proof of identity.
- Inactive staff remain visible in history but cannot be selected for new completions.
- Staff display names can be edited; existing completions keep their snapshot staff names.

### TaskList

Represents a staff-facing checklist/list.

Suggested fields:

- `name`
- `key`
- `position`
- `active`
- `notes`

Rules:

- Generate a stable unique `key` from the name.
- Archive lists by setting `active: false`, not by deleting historical records.
- Archiving a list archives active tasks in that list.
- Archived lists can be reactivated, but reactivating a list does not automatically reactivate its archived tasks.
- A list can have many tasks and many task occurrences.
- Lists are freely named operating groups, not hard-coded types.
- Each task belongs to exactly one task list in v1.
- Lists sort by `position`.
- List names can be edited; occurrences keep snapshot list names for history.

### Task

Represents the reusable task definition. For recurring tasks, this is the schedule source.

Suggested fields:

- `task_list_id`
- `title`
- `instructions`
- `position`
- `active`
- `requires_photo_evidence`
- `recurrence_type`
- `starts_on`
- `ends_on`
- `due_time`
- `weekdays`
- `one_time_on`

Recommended recurrence types:

- `one_time`
- `daily`
- `weekly`
- `monthly`

Rules:

- Keep recurrence logic intentionally boring for v1.
- `weekdays` can be a JSON array of integers for weekly recurrence.
- Monthly recurrence means once during each calendar month.
- Validate that the needed schedule fields exist for each recurrence type.
- Editing a task should affect future/open occurrences only. Completed and missed occurrences are historical evidence.
- Instructions are plain text, not rich text or nested checklist steps.
- Tasks sort by due time and position on the staff board.
- Archive tasks by setting `active: false`, not by deleting historical records.
- When a task is archived, remove or hide open uncompleted current/future occurrences. Do not add a canceled state in v1.
- Archived tasks can be reactivated; reactivation affects future/on-demand occurrences only and does not alter history.

### TaskOccurrence

Represents one dated instance of a task. This is the history anchor.

Suggested fields:

- `task_id`
- `task_list_id`
- `period_kind`
- `period_starts_on`
- `period_ends_on`
- `due_at`
- `completion_window_ends_at`
- `snapshot_title`
- `snapshot_instructions`
- `snapshot_list_name`
- `requires_photo_evidence`
- `position`

Rules:

- Unique index on `task_id`, `period_kind`, and `period_starts_on`.
- Use `period_kind: "day"` for one-time, daily, and weekly occurrences.
- Use `period_kind: "month"` for monthly occurrences.
- Store snapshot fields so old history still says what staff actually saw even if a manager later edits the task.
- Keep completed and missed occurrences stable when a task is edited.
- Open future occurrences may be updated or regenerated from the edited task.
- Snapshot the task list name on each occurrence.
- Do not destroy completed occurrences when a task or list is archived.
- Treat occurrences as the source of historical truth for a specific day.
- `due_at` must include date and time.
- `due_at` can be nil for monthly occurrences because they can be completed any time in the month.
- `completion_window_ends_at` controls when an occurrence becomes missed/locked.
- Daily and weekly occurrences set `completion_window_ends_at` to the next local midnight.
- One-time occurrences set `completion_window_ends_at` to nil so they roll forward until completed or archived.
- Monthly occurrences set `completion_window_ends_at` to local midnight when the next calendar month begins.
- One task creates at most one occurrence per operating day.
- A monthly task creates one occurrence for the calendar month.
- Monthly occurrences are missed and locked at local midnight when the next calendar month begins.
- Monthly occurrences remain open until the next calendar month begins.
- Do not store operational status on task occurrences in v1.
- Compute status from active completion, `due_at`, `completion_window_ends_at`, and the current time.
- Implement status display and filtering with model methods and simple scopes; Ruby filtering is acceptable for MVP-sized date ranges when the SQL would add unnecessary complexity.
- Display an occurrence as late when it has no active completion, its `due_at` time is in the past, and it is not missed.
- Display a daily or weekly occurrence as missed after its operating day closes.
- Reject completion for missed occurrences, but allow late completion during the same operating day.
- Use local calendar midnight as the v1 operating-day boundary.
- For one-time tasks, keep the occurrence late and completable across operating days until it is completed.

### TaskCompletion

Represents the evidence that one occurrence was done.

Suggested fields:

- `task_occurrence_id`
- `staff_member_id`
- `snapshot_staff_name`
- `completed_at`
- `notes`
- `undone_at`
- `undone_note`
- `undone_by_staff_member_id`
- `snapshot_undone_by_staff_name`

Rules:

- Use one `task_completions` table for active and undone completions.
- Scope active completions where `undone_at` is null.
- Enforce one active completion per occurrence with a partial unique index on `task_occurrence_id` where `undone_at IS NULL`.
- Store both `staff_member_id` and `snapshot_staff_name` so history remains readable if a staff member is renamed or deactivated.
- Store both `undone_by_staff_member_id` and `snapshot_undone_by_staff_name` when a completion is undone.
- Use `has_one_attached :photo`.
- Validate photo presence when the occurrence requires photo evidence.
- Support one photo per completion in v1, not multiple photos.
- Do not allow photo evidence to be added after completion in v1.
- Do not add optional photos to normal tasks in v1.
- Completing a task should create the completion in one transaction; completed status is derived from the active completion.
- One occurrence can have at most one active completion.
- Allow undoing a completion with an explicit confirmation step.
- Reject undo after the occurrence's operating day has closed.
- Keep undone completions and their photo evidence as historical evidence instead of deleting them.
- Allow an optional undo note.
- Require Completing As for undo so the undo action has staff attribution.
- After undo, return the occurrence to open or late and allow same-day re-completion.
- Do not add assigned-staff behavior in v1.

## Occurrence Generation

Add a small service, for example `Tasks::OccurrenceBuilder`, that materializes occurrences idempotently for a date range.

Responsibilities:

- Accept `from:` and `to:` dates.
- Find active tasks whose recurrence overlaps the range.
- Create missing occurrences with snapshot fields.
- Leave completed occurrences untouched.
- Avoid duplicate occurrences.

Use this service when loading:

- today's task board
- a specific date view
- history date ranges

For v1, build occurrences on demand only. Do not require a background worker. A later job can prebuild upcoming occurrences after the module is stable.

Board-generation rules:

- Loading `/tasks` generates today's one-time, daily, and weekly occurrences.
- Loading `/tasks` generates current-month monthly occurrences.
- Loading `/tasks` does not generate future daily or weekly occurrences.
- Loading history generates only the requested date range and monthly windows needed for that range.

## UI Plan

Routes:

- `/tasks` staff board
- `/tasks/history`
- `/tasks/staff`
- `/tasks/lists`
- `/tasks/manage`

### Tasks Dashboard

Route: `/tasks`

Purpose:

- The staff-facing today view.
- Provide a board-level Completing As selector for choosing the active staff member credited with completions.
- Persist Completing As in the browser session or cookie until changed, while keeping it visible and easy to change.
- Show tiny board metrics: open today, late today, completed today, and open this month.
- Group due tasks by list.
- Show open monthly tasks in a separate This Month section.
- Show clear states: open, late, completed, missed.
- Move late tasks to the top of their task list with a clear Late badge.
- Show rolled-forward one-time late tasks at the top of their normal task list until completed or archived.
- Keep completed tasks visible on today's board, visually de-emphasized with completed-by and completed-at.
- Provide an undo action for completed tasks with confirmation.
- Hide or disable undo after the same operating day closes.
- Do not show missed tasks from previous days on today's staff board; show them in history.
- Hide completed monthly tasks from the This Month section after completion; keep them visible in history.
- Make photo-required tasks obvious.
- Use large tap targets and simple language.
- Do not add auto-refresh in v1; a normal page refresh or visible refresh link is enough.

Completion behavior:

- Normal task: staff selects Completing As once and taps complete.
- Photo-required task: staff selects Completing As once, attaches/takes a photo, then completes.
- Use a camera-friendly file input with `accept="image/*"` and capture hints where practical.
- Do not build custom camera UI in v1.
- Notes stay optional in v1.
- If no active staff member is selected as Completing As, require selection before completing a task.
- Completing As persistence is a convenience feature, not authentication.

### Task Lists

Purpose:

- Manager setup for lists such as Opening, Closing, Cleaning, Prep, Food Safety.
- Create/edit/archive lists.
- Keep the list UI simple and close to the current order-guide management style.

### Tasks

Purpose:

- Manager setup for the recurring task definitions.
- Form fields: title, instructions, list, recurrence, due time or monthly deadline, starts on, ends on, requires photo evidence.
- Avoid exposing complicated recurrence rules in v1.

### Task History

Purpose:

- Answer: "What was done yesterday, last week, or last year?"
- Default to the last seven local calendar days.
- Filter by date range, status, and task list in v1.
- Show list, task, status, completed by, completed at, notes, and whether photo evidence exists.
- Link to an occurrence detail page when photo evidence or longer notes need review.
- Show only a photo-attached indicator in the main history list.
- Display active and undone completion photos on the occurrence detail page.
- Show undone completions and their kept photo evidence on the occurrence detail page, not inline in the main history list.

## Implementation Steps

### Checkpoint 1: Task Foundation

1. Add Active Storage support
   - Uncomment Active Storage in `config/application.rb` if still skipped.
   - Install/add the Active Storage migrations.
   - Confirm local disk storage stays under ignored app storage.
   - Use local disk storage for MVP/dev and leave production cloud storage decisions for later.

2. Add database migrations and models
   - `StaffMember`
   - `TaskList`
   - `Task`
   - `TaskOccurrence`
   - `TaskCompletion`
   - Add validations, associations, scopes, and key generation.

3. Add occurrence generation service
   - Implement recurrence expansion for one-time, daily, weekly, and monthly tasks.
   - Test idempotency and date-range behavior.
   - Test that generated occurrences snapshot the current task/list fields.
   - Test one-time rollover, daily/weekly missed behavior, and monthly calendar-month windows.

### Checkpoint 2: Staff Task Board

4. Add staff-facing task board
   - Add `/tasks`.
   - Add Today grouped by task list.
   - Add This Month for open monthly tasks.
   - Add Completing As selector.
   - Show open, late, completed, and missed states where applicable.

5. Add completion workflow
   - Add completion service or controller transaction.
   - Enforce photo evidence on required tasks.
   - Store staff member and timestamp.
   - Keep completed historical rows stable.
   - Add same-operating-day undo with confirmation and optional undo note.

### Checkpoint 3: Task Setup and History

6. Add setup pages
   - Add Tasks nav item.
   - Add simple staff member setup pages.
   - Add list/task management pages.

7. Add history pages
   - Add task history with date range, status, and task list filters.
   - Add occurrence detail page.
   - Show active and undone completion photo evidence on detail.

8. Add seeds and fixtures
   - Generic demo lists and tasks only for development/test.
   - Generic demo staff only for development/test.
   - Keep production installs empty until staff/lists/tasks are created through setup or private install data.
   - No real restaurant, employee, customer, vendor, or private photo data.

9. Add tests
   - Model validations and associations.
   - Recurrence builder service tests.
   - Completion workflow tests, including photo-required rejection.
   - Integration tests for today view, task completion, and history.

10. Run verification
   - `bin/check-no-npm-surface`
   - `bin/rails test`
   - `bin/rubocop`
   - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

## Non-Goals For This Version

- Shift scheduling.
- Payroll, tips, or labor compliance.
- Employee availability.
- Time clock.
- Enforced manager-only setup permissions.
- Individual staff task assignment.
- Task pause/suspension date ranges.
- Inventory model integration.
- Staff-member history filtering.
- Task title search.
- Task CSV import/export.
- Dedicated printable checklist workflow.
- Push notifications.
- Live updates or auto-refresh.
- Multi-location tenant management.
- Location modeling.
- Native mobile app.
- Custom camera UI.
- Complex custom recurrence builder.
- Role-based permission security.
- AI-generated tasks.

## Risks And Decisions To Keep Plain

- There is no authentication in the app yet. Staff selection records who is credited with a task, but it does not prove identity.
- Task setup is not permission-protected in v1. Treat the MVP as an internal trusted tool until authentication and roles exist.
- Photo evidence may contain private operational details. Keep uploads out of tracked files and avoid adding real photos to tests or seeds.
- Recurrence can become complex quickly. Start with one-time, daily, weekly, and monthly; do not build every possible scheduling rule.
- Missed task history is only as good as occurrence materialization. The on-demand builder must create needed date ranges, and a daily job can be added later for stronger operational reliability.
- Completed occurrence rows are historical records. Prefer archiving and future-effective edits over rewriting history.
- Late daily and weekly occurrences are still actionable during the same operating day. Late one-time occurrences remain actionable across days until completed. Missed occurrences are historical records and cannot be completed after their completion window closes.

## First Useful Restaurant Workflow

Use this as the target smoke test:

1. Create staff members `Demo Manager` and `Demo Staff`.
2. Create lists `Opening`, `Closing`, and `Cleaning`.
3. Create an `Opening` task named `Check front display case` that repeats daily and does not require a photo.
4. Create a `Cleaning` task named `Send photo of cleaned slicer` that repeats daily and requires a photo.
5. Visit `/tasks`.
6. Complete the display case task without a photo.
7. Try to complete the slicer task without a photo and confirm it fails.
8. Complete the slicer task with a photo.
9. Visit task history for today and confirm both completions show who did them and when.
