# Log Book Module Plan

## Goal

The Log Book Module gives a restaurant one daily operating record that is structured enough to review quickly, but flexible enough for each store to decide what matters.

It should replace loose group-chat notes for manager handoffs, daily incidents, maintenance issues, food-safety notes, unusual inventory counts, and owner follow-ups.

## Core Concept

The module has two layers:

1. **Log Book Template**
   - Configured by an admin or manager.
   - Defines the sections that appear each day.
   - Examples: General Log, Maintenance, Bagels Left, Food Safety, Customer Issues, Equipment, Vendor Notes.

2. **Daily Log Book Entry**
   - Filled out by the current manager or authorized staff.
   - One operating-day record with one response per active template section.
   - Can be reviewed the next day by the next manager.

This is intentionally separate from the Inventory Module. A field like "Bagels left" can be a lightweight daily operating signal without becoming a full inventory count.

## Language

Use these terms in the app:

- **Log Book**
- **Log Section**
- **Daily Entry**
- **Response**
- **No note today**
- **Flag for follow-up**
- **Urgency**

Avoid these terms:

- Form builder
- Custom field
- Schema
- Survey
- Ticket

## Section Types

Start with a small set of section types. More can be added later if real use demands it.

### Long Text

Best for:

- General Log
- Maintenance
- Manager Notes
- Customer Issues
- Staff Notes

Behavior:

- Shows a text area.
- Supports "No note today."
- Can be flagged for follow-up.

### Number

Best for:

- Bagels left
- Cash drawer variance
- Temperature reading
- Waste count

Behavior:

- Shows a numeric input.
- Optional unit label, such as `bagels`, `degrees F`, `dollars`, `cases`.
- Optional guidance text.
- Can be flagged for follow-up.

### Short Text

Best for:

- Vendor reference
- Equipment name
- Simple one-line status

Behavior:

- Shows a single-line input.
- Supports "No note today."
- Can be flagged for follow-up.

### Yes / No

Best for:

- Walk-in checked?
- Bathroom checked?
- Safe counted?

Behavior:

- Shows Yes, No, and No note today.
- Optional comment field if the answer needs detail.
- Can be flagged for follow-up.

## Daily UX

The daily log screen should feel like a fast manager handoff form:

1. Header shows the operating day.
2. Each active Log Section appears as a clear block.
3. Each block has:
   - section label
   - optional helper text
   - the input control
   - a "No note today" option when the section allows it
   - a "Flag for follow-up" toggle
   - optional urgency selector when flagged
4. Save action updates the whole daily entry.
5. Save is available only for the current operating day.
6. Past operating days are read-only history.
7. Submitted sections should be readable immediately below or in a review mode.

On mobile, each section should be large, uncluttered, and easy to tap while standing in the store.

## Admin UX

Admins need a setup screen for Log Sections:

- Create a section.
- Edit label and helper text.
- Choose section type.
- Set whether the section is required.
- Set whether "No note today" is allowed.
- Set display order.
- Archive sections without deleting historical responses.

Archived sections should disappear from future days but remain visible on old daily entries.

## Follow-Up Behavior

Flagging a response should create a follow-up signal.

For the first version:

- Show flagged responses on the Log Book dashboard.
- Show flagged responses on the main Dashboard.
- Track urgency as `normal`, `important`, or `urgent`.
- Allow a manager/admin to mark the follow-up resolved.

Later:

- Email or push notifications.
- Assign follow-ups to a person.
- Carry unresolved follow-ups into the next day's Log Book.

## Data Model Draft

### log_book_sections

- `id`
- `title`
- `description`
- `section_type`
- `position`
- `required`
- `allow_no_note`
- `unit_label`
- `active`
- `created_by_id`
- timestamps

### log_book_entries

- `id`
- `operating_date`
- `submitted_by_id`
- `submitted_at`
- timestamps

One entry per operating date for the current single-context restaurant.

Only the current operating day's entry can be edited. Older entries remain visible for review, but cannot be changed through the normal Log Book UI.

### log_book_responses

- `id`
- `log_book_entry_id`
- `log_book_section_id`
- `section_title_snapshot`
- `section_type_snapshot`
- `value_text`
- `value_number`
- `no_note`
- `flagged_for_follow_up`
- `urgency`
- `follow_up_resolved_at`
- `follow_up_resolved_by_id`
- timestamps

Snapshots are important because changing a section label later should not rewrite old log history.

## Permissions

Use the existing `log_book` module permission for access.

First version:

- Admins can configure sections.
- Anyone with Log Book access can fill out the current operating day's daily entry.
- Anyone with Log Book access can read past entries.
- No one can update past entries through the normal Log Book workflow, including admins.
- Admins can resolve follow-ups.

Later:

- Separate "can configure log book" from "can write daily log."
- Separate "can resolve follow-ups" from "can write responses."

## MVP Scope

Build this first:

1. Admin-managed Log Sections.
2. Daily Log Book page generated from active sections.
3. Text, number, short text, and yes/no section types.
4. No note today.
5. Flag for follow-up with urgency.
6. Dashboard card for unresolved follow-ups.
7. Tests for template setup, daily entry saving, archived-section history, permission gating, and read-only past entries.

Do not build notifications in the MVP. Store the urgency and follow-up state first, then add notification channels after the workflow is proven.

## Product Decisions

- The default seed should include General Log, Maintenance, and Follow-ups.
- Bagels Left should be an example custom numeric section, not hard-coded into the product.
- "No note today" is better language than "Not applicable" for restaurant staff. It reads less like paperwork and more like a manager handoff.
- The module should not try to replace full inventory counts, task completion, or food-safety compliance records. It is a daily narrative and signal layer.
