# Tasks Module Implementation Prompt and Plan

This plan is for adding a 7tasks-style staff task system as a new module inside the existing Rails app. The first version should be useful for a real restaurant without turning Inventory OS into a generic platform too early.

## Copy-Paste Implementation Prompt

You are working in the `restaurant-inventory-os` Rails app. Build the first production-minded version of a Tasks module for restaurant staff.

The product direction is a future restaurant operations super app with separate modules. The existing Inventory module handles inventory counts, order guides, purchasing, receipt imports, and price intelligence. The new Tasks module should live beside Inventory as its own bounded module, not replace or rewrite the existing inventory/purchasing code. A future Schedule module may exist later, but do not build scheduling, shifts, payroll, availability, or timeclock features now.

Core user story:

- A manager creates task lists such as Opening, Closing, Cleaning, Prep, Food Safety, or Weekly Deep Clean.
- A manager creates tasks inside those lists.
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
- Prefer model names that are clear in the restaurant domain:
  - `TaskList`
  - `TaskTemplate`
  - `TaskOccurrence`
  - `TaskCompletion`
  - `StaffMember`
- Do not create a generic plugin architecture yet.
- Do not call the future scheduling module into existence. `StaffMember` is allowed only because task completion needs to record who did the work.
- Enable Active Storage for task completion photos instead of adding an image-upload dependency.

Acceptance criteria for the first useful version:

- Navigation includes a Tasks module entry.
- `/tasks` shows today's due tasks grouped by active task list.
- Managers can create, edit, archive, and reorder task lists.
- Managers can create and edit task templates with title, instructions, list, recurrence, due time, active flag, and photo-required flag.
- Staff can complete a due task by selecting an active staff member.
- Photo-required tasks reject completion without an attached photo.
- Completed tasks store completed-by, completed-at, notes, and photo evidence when present.
- History can be filtered by date or date range and shows completed, incomplete, skipped, or missed occurrences.
- Editing a recurring task does not rewrite already completed history.
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

Do not build a separate engine, API-only app, JavaScript app, or multi-module registry yet. The super-app direction can be supported by clean navigation and namespacing first.

## Recommended Data Model

### StaffMember

Represents a person who can complete tasks. This is not an authentication system.

Suggested fields:

- `display_name`
- `role`
- `active`
- `notes`

Rules:

- Require `display_name`.
- Keep seeded/test staff generic, such as `Demo Manager` and `Demo Staff`.
- Real staff names are install data in the database, not tracked source.

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
- A list can have many task templates and many task occurrences.

### TaskTemplate

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
- `day_of_month`
- `one_time_on`

Recommended recurrence types:

- `one_time`
- `daily`
- `weekly`
- `monthly`

Rules:

- Keep recurrence logic intentionally boring for v1.
- `weekdays` can be a JSON array of integers for weekly recurrence.
- `day_of_month` can support monthly recurrence.
- Validate that the needed schedule fields exist for each recurrence type.
- Editing a template should affect future occurrences only. Completed occurrences are historical evidence.

### TaskOccurrence

Represents one dated instance of a task. This is the history anchor.

Suggested fields:

- `task_template_id`
- `task_list_id`
- `scheduled_on`
- `due_at`
- `status`
- `snapshot_title`
- `snapshot_instructions`
- `snapshot_list_name`
- `requires_photo_evidence`
- `position`

Recommended statuses:

- `open`
- `completed`
- `skipped`
- `canceled`

Rules:

- Unique index on `task_template_id` and `scheduled_on`.
- Store snapshot fields so old history still says what staff actually saw even if a manager later edits the template.
- Do not destroy completed occurrences when a template or list is archived.

### TaskCompletion

Represents the evidence that one occurrence was done.

Suggested fields:

- `task_occurrence_id`
- `staff_member_id`
- `completed_at`
- `notes`

Rules:

- Unique index on `task_occurrence_id` for v1.
- Use `has_one_attached :photo`.
- Validate photo presence when the occurrence requires photo evidence.
- Completing a task should create the completion and mark the occurrence `completed` in one transaction.

## Occurrence Generation

Add a small service, for example `Tasks::OccurrenceBuilder`, that materializes occurrences idempotently for a date range.

Responsibilities:

- Accept `from:` and `to:` dates.
- Find active task templates whose recurrence overlaps the range.
- Create missing occurrences with snapshot fields.
- Leave completed occurrences untouched.
- Avoid duplicate occurrences.

Use this service when loading:

- today's task board
- a specific date view
- history date ranges

Optional later improvement:

- Add a Solid Queue recurring job to prebuild the next 14 days of occurrences and backfill yesterday, but the first version should still work without a background worker by building on demand.

## UI Plan

### Tasks Dashboard

Route: `/tasks`

Purpose:

- The staff-facing today view.
- Group due tasks by list.
- Show clear states: open, completed, missed, skipped.
- Make photo-required tasks obvious.
- Use large tap targets and simple language.

Completion behavior:

- Normal task: staff selects their name and taps complete.
- Photo-required task: staff selects their name, attaches/takes a photo, then completes.
- Use a file input with image accept/capture hints where practical.

### Task Lists

Purpose:

- Manager setup for lists such as Opening, Closing, Cleaning, Prep, Food Safety.
- Create/edit/archive lists.
- Keep the list UI simple and close to the current order-guide management style.

### Task Templates

Purpose:

- Manager setup for the recurring task definitions.
- Form fields: title, instructions, list, recurrence, due time, starts on, ends on, requires photo evidence.
- Avoid exposing complicated recurrence rules in v1.

### Task History

Purpose:

- Answer: "What was done yesterday, last week, or last year?"
- Filter by date or date range.
- Show list, task, status, completed by, completed at, notes, and whether photo evidence exists.
- Link to an occurrence detail page when photo evidence or longer notes need review.

## Implementation Steps

1. Add Active Storage support
   - Uncomment Active Storage in `config/application.rb` if still skipped.
   - Install/add the Active Storage migrations.
   - Confirm local disk storage stays under ignored app storage.

2. Add database migrations and models
   - `StaffMember`
   - `TaskList`
   - `TaskTemplate`
   - `TaskOccurrence`
   - `TaskCompletion`
   - Add validations, associations, scopes, and key generation.

3. Add occurrence generation service
   - Implement recurrence expansion for one-time, daily, weekly, and monthly tasks.
   - Test idempotency and date-range behavior.
   - Test that generated occurrences snapshot the current template/list fields.

4. Add completion workflow
   - Add completion service or controller transaction.
   - Enforce photo evidence on required tasks.
   - Store staff member and timestamp.
   - Keep completed historical rows stable.

5. Add routes, controllers, and views
   - Add Tasks nav item.
   - Add staff-facing today board.
   - Add list/template management pages.
   - Add history page and occurrence detail page.

6. Add seeds and fixtures
   - Generic demo lists and tasks only.
   - Generic demo staff only.
   - No real restaurant, employee, customer, vendor, or private photo data.

7. Add tests
   - Model validations and associations.
   - Recurrence builder service tests.
   - Completion workflow tests, including photo-required rejection.
   - Integration tests for today view, task completion, and history.

8. Run verification
   - `bin/check-no-npm-surface`
   - `bin/rails test`
   - `bin/rubocop`
   - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

## Non-Goals For This Version

- Shift scheduling.
- Payroll, tips, or labor compliance.
- Employee availability.
- Time clock.
- Push notifications.
- Multi-location tenant management.
- Native mobile app.
- Complex custom recurrence builder.
- Role-based permission security.
- AI-generated tasks.

## Risks And Decisions To Keep Plain

- There is no authentication in the app yet. Staff selection records who completed a task, but it does not prove identity.
- Photo evidence may contain private operational details. Keep uploads out of tracked files and avoid adding real photos to tests or seeds.
- Recurrence can become complex quickly. Start with one-time, daily, weekly, and monthly; do not build every possible scheduling rule.
- Missed task history is only as good as occurrence materialization. The on-demand builder must create needed date ranges, and a daily job can be added later for stronger operational reliability.
- Completed occurrence rows are historical records. Prefer archiving and future-effective edits over rewriting history.

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
