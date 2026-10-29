---
name: meeting-notes
description: Turn meetings into structured Markdown notes filed by project. Finds meetings from any connected calendar (Google Calendar, Outlook/Microsoft 365) or straight from transcripts, pulls transcripts from any connected notetaker (Granola, Fireflies, Otter, Fathom, Zoom, ...) or from transcript files dropped in an inbox folder, then writes notes.md + transcript.md into Meetings/<folder>/ and keeps index.md and each _project.md current. Works with no connectors at all (inbox files only). Use for a scheduled run, when the user types /meeting-notes (optionally with a date, range, "init", "setup", "review" or "status"), or asks to process, file or catch up on meeting notes.
---

# Meeting Notes Agent

One job: every meeting the user attended becomes a structured note, filed in the right folder. Nothing else.

This skill is tool-agnostic. It never assumes a specific connector, operating system, folder or account. It discovers what is available, uses the best option, and degrades gracefully.

Paths in this file:
- `<skill>/…` = this skill's own directory (where this SKILL.md lives).
- `<ws>/…` = the user's **workspace**, the folder holding their meetings (resolved below).

## Supporting files

| File | Read when |
|---|---|
| `<skill>/references/providers.md` | Preflight: finding the calendar and transcript sources |
| `<skill>/references/note-template.md` | Writing any `notes.md` or `transcript.md` |
| `<skill>/references/routing.md` | Choosing a folder; Setup and Review modes |
| `<skill>/references/indexes.md` | Updating the ledger, `index.md`, monthly logs, `_project.md` |
| `<skill>/templates/*` | Creating a new workspace (Init) |

## Workspace

Resolve `<ws>` in this order and use the first that applies:

1. A path the user gave in this request (e.g. `/meeting-notes --dir ~/Notes/Meetings`).
2. The environment variable `MEETING_NOTES_DIR` (check with `echo "$MEETING_NOTES_DIR"`).
3. `Meetings/` in the current working directory.

If `<ws>/config.md` doesn't exist, run **Init** first.

**No writable local filesystem** (e.g. a plain chat with no file access): you can still process meetings, but you can't file them persistently. Produce each `notes.md` as a downloadable file, skip the indexes and the ledger, and tell the user once that persistent filing needs a local folder (Claude Code, Claude desktop, or Cowork).

### Workspace layout

```
<ws>/
├── config.md            settings (user-editable)
├── routing.md           folder rules (user-editable)
├── _pending.md          items waiting for the user's review
├── index.md             open action items + last 30 days (generated)
├── _log/YYYY-MM.md      full monthly meeting lists (generated)
├── .ledger.jsonl        one line per processed meeting (machine state)
├── _inbox/              transcript files dropped by the user or other tools
├── _unsorted/           meetings with no clear folder
└── <Folder>/
    ├── _project.md      folder overview (generated)
    └── YYYY-MM-DD_slug/
        ├── notes.md
        └── transcript.md
```

## Modes

| Invocation | Mode |
|---|---|
| Scheduled task, or no argument | **Run**: today + catch-up window |
| A date (`2026-10-27`) or range (`2026-10-20..2026-10-24`) | **Run** for those days |
| `init` | **Init**: create the workspace |
| `setup` | **Setup**: first routing proposal |
| `review` | **Review**: pending folders and moves |
| `status` | **Status**: report sources found, workspace, pending items; change nothing |

**Unattended** = a scheduled or headless run (no user in the conversation). It must never stop to ask a question; it queues anything that needs the user in `<ws>/_pending.md`. When a run is **on demand** and `_pending.md` has open items, offer a Review first.

## Mode: Init

1. Create `<ws>` and copy everything from `<skill>/templates/` into it (`config.md`, `routing.md`, `_pending.md`, `index.md`). Create the empty folders `_inbox/`, `_unsorted/`, `_log/` and an empty `.ledger.jsonl`.
2. Fill in `owner_name`, `owner_email` and `timezone` in `config.md` if a calendar is available. Otherwise ask the user (on demand) or leave them blank (unattended).
3. Tell the user where the workspace is and what sources were found (see Preflight). Suggest `setup` once a calendar is connected.

Init never overwrites existing files.

## Preflight (every mode)

1. **Resolve `<ws>`** and read `config.md`. Fall back to the defaults in `<skill>/templates/config.md` for any missing key, so older workspaces keep working after updates.
2. **Discover sources** with `<skill>/references/providers.md`:
   - a **calendar** source (optional),
   - **transcript sources** in the order listed under `sources` in config (by default: any connected notetaker, then the `_inbox/` folder).
3. **Pick the meeting list strategy:**
   - Calendar found → **calendar-first** (the calendar decides which meetings happened).
   - No calendar → **transcript-first**: every transcript found for the day is a meeting. Title, time and attendees come from the transcript source's metadata or the file. There are no placeholder notes in this mode, since nothing tells you about unrecorded meetings.
   - Nothing at all (no calendar, no notetaker, empty inbox) → report that nothing was found, say how to add a source, and stop.
4. Read `routing.md` and the ledger.

Never fail the whole run because one source errors. Note the error, continue with the other sources, and include it in the summary.

## Mode: Run

Work out the days in scope: today plus the previous `catch_up_days` (or the requested date/range). Use `timezone` from config, or the calendar's timezone, for "today" and all dates.

Build the list of candidate meetings for those days (calendar-first or transcript-first). Drop the following:
- events the owner declined or didn't respond to, all-day events, out-of-office, cancelled, events with no other attendees, and events that haven't ended yet;
- **sensitive meetings**: the title or description contains any `sensitive_keywords` entry (case-insensitive, whole word). Write nothing for them, not even an index entry. Count them as "skipped (private)".
- meetings already in the ledger with `status: complete`.

Process the oldest first, up to `max_meetings_per_run`. If more remain, leave them for the next run and say so in the summary; the catch-up window will pick them up.

For **each** meeting, finish all of these steps before starting the next one, so an interrupted run can resume safely:

1. **Meeting id.** Use the calendar event id. In transcript-first mode, use `<source>:<source id>`, or `file:<filename>` for inbox files.
2. **Transcript.** Try each transcript source in config order and stop at the first match:
   - connector sources: the recording whose start time is within `match_window_minutes` of the meeting start; break ties by closest title;
   - `_inbox/`: a file whose timestamp (filename first, then file metadata) falls within the meeting's start–end ± `match_window_minutes`.

   No match → placeholder note (calendar-first only).
3. **Folder.** If the ledger already has this meeting as a placeholder, keep its folder. Otherwise pick one with `<skill>/references/routing.md`; this may create a folder and a pending rule.
4. **Write files** in `<ws>/<folder>/YYYY-MM-DD_slug/`. The slug is the title, lowercased and hyphenated, ASCII only, max 50 characters; add `-2`, `-3`… if a different meeting already uses that folder.
   - `transcript.md`: a small header, then the transcript as received. Don't clean it up or summarize it. If it came from `_inbox/`, move the file's content here and delete the inbox file.
   - `notes.md`: follow `<skill>/references/note-template.md` exactly.
   - Upgrading a placeholder: write `transcript.md`, then rewrite `notes.md` as a full note.
5. **Ledger.** Add or replace this meeting's line in `.ledger.jsonl`, using the format in `<skill>/references/indexes.md`. The meeting counts as done only once its ledger line is written.

After all meetings:

6. **Indexes.** Update `index.md`, the affected `_log/YYYY-MM.md` files and the affected `_project.md` files, following `<skill>/references/indexes.md`. Only touch folders and months that changed in this run.
7. **Leftover inbox files** older than the catch-up window that never matched: leave them, and report the count.
8. **Notify.** If anything changed and `notify` isn't `off`, send one desktop notification (≤150 characters, e.g. `4 meetings filed · 1 waiting on transcript · 6 new action items · 1 folder to review`), using the first of these that exists:
   - macOS: `osascript -e 'display notification "<msg>" with title "Meeting notes"'`
   - Linux: `notify-send "Meeting notes" "<msg>"`
   - Windows: `powershell -NoProfile -Command "New-BurntToastNotification -Text 'Meeting notes','<msg>'"`; if that module is missing, skip it.

   If none of them work, skip the notification silently. The summary still goes in the reply or run log.
9. **Reply** (on demand): the same summary, links to each new `notes.md`, any source errors, and the number of pending review items.

### Writing good notes

- Use only the transcript, the invite, and the notetaker's own notes. Never invent decisions, owners, dates or numbers. Anything unclear goes under Open questions.
- Every action item needs an owner: the attendee's name as spoken or as listed on the invite, or `@unassigned`. Only add a due date if one was said.
- Keep the TL;DR to 2–3 sentences, and group the Discussion by topic, not as a timeline.
- Write in the language the meeting was held in.

## Mode: Setup

The one-time routing proposal. Always on demand, and the user approves before anything is written. It works best with a calendar; without one, base the proposal on the transcripts in the ledger.

1. Gather the last `setup_lookback_days` of meetings (same filters as Run, sensitive meetings excluded).
2. Propose folders using `<skill>/references/routing.md` → "Proposing rules".
3. Show a table of each folder's name, its rules, how many meetings it would catch, and 2–3 example titles. Also list what would stay unsorted.
4. Let the user approve, rename, merge, split or drop folders.
5. On approval, write the rules to `routing.md` with `status: active` and create the folders, each with an empty `_project.md`.
6. Offer to backfill that period now (a Run over the range). Don't start it unasked.

## Mode: Review

Works through `_pending.md`. Always on demand.

1. **Pending folders** the agent created on its own: show each one with its rule and the meetings in it. The user can approve (`status: active`), rename, merge into another folder, or reject (the meetings are re-routed or go to `_unsorted/`).
2. **Before moving anything**, show a preview ("N meetings will move: A → B"). Move only after the user confirms, then update the ledger, every affected `_project.md`, the cross-links, `index.md` and the `_log` files.
3. Tick off the items you handled in `_pending.md`.

## Mode: Status

Report the workspace path, which calendar and transcript sources were found (and which are missing), the last run (the newest `updated` in the ledger), how many items are in the inbox, how many placeholder notes there are, and open `_pending.md` items. Change nothing.

## Hard rules

- Never edit the body of a `notes.md` with `status: complete`; the user may have edited it. The only allowed change is its front matter (`folder`, `also_in`) during a confirmed move.
- Never write anything for a sensitive meeting.
- Never move filed meetings without a preview and confirmation.
- Never ask questions during an unattended run.
- Calendar and notetaker sources are read-only: never create, edit or delete events or recordings.
- Never delete a folder that still contains meetings.
- Never put personal data from meetings into anything outside `<ws>`: no URLs, no other files, no external services.
