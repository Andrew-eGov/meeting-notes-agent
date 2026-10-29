# Meeting Notes Agent: Design

## Intent

One job, done clearly: turn every meeting a person attended into structured Markdown notes, filed in the right project folder, with nothing for them to do after the meeting.

The agent has to work for anyone: any Claude account, any machine, any calendar, any notetaker, and with no connectors at all. More capabilities may be added later, so this job stays a clearly separate step.

## Goals

- Every attended meeting gets a note. When a calendar is connected, meetings without a transcript get a placeholder that is filled in later.
- Notes follow one consistent template.
- Notes and transcripts land in the right folder automatically, based on rules the user approved.
- Open action items are visible in one place, per project and overall.
- It works out of the box with zero connectors (transcript files in an inbox) and gets better as connectors are added.
- It stays fast and safe as the archive grows into thousands of meetings.

## Non-goals

- Different templates for different meeting types (one template for all).
- Sending notes to other people, email or chat.
- Editing calendar events or notetaker recordings: the agent is read-only on all sources.
- Hosting or cloud execution: it runs where the user's files are.

## Anti-goals (failure, even if it "works")

- Overwriting notes the user has edited.
- Saving anything for sensitive meetings (HR, legal, personal, interviews, …).
- Piling up near-duplicate project folders.
- Moving filed meetings without showing the user first.
- Breaking for a user because they use a different calendar, notetaker or operating system.

## Decisions

| Area | Decision |
|---|---|
| Format | A single Agent Skill (`SKILL.md` plus references and templates), shipped as a Claude Code plugin, an uploadable skill zip, and plain files |
| Triggers | On demand (`/meeting-notes` with optional date, range, `init`, `setup`, `review`, `status`) and any scheduler (desktop app, cron, Task Scheduler) |
| Which meetings | Calendar-first when a calendar is connected (all accepted meetings with other attendees). Transcript-first when not |
| Lookback | Today plus `catch_up_days` (default 7), capped at `max_meetings_per_run` (default 25) |
| Transcript sources | Any notetaker connector, found by capability, then the `_inbox/` folder (Wispr, Zoom downloads, voice memos, …). Order is set in config |
| Workspace | `--dir`, then `$MEETING_NOTES_DIR`, then `./Meetings` |
| Layout | `<Folder>/YYYY-MM-DD_slug/` with `notes.md` and `transcript.md`; `_unsorted/` for meetings with no clear project |
| Note sections | Front matter, TL;DR, Decisions, Action items (owner, due date), Discussion, Open questions |
| Re-runs | The ledger records what's done. Completed notes are never touched; placeholders are upgraded when a transcript appears |
| Sensitive meetings | A keyword list in config; matching meetings are skipped entirely |
| Notifications | macOS, Linux or Windows desktop notification if available, otherwise none |

## Routing to folders

- Rules live in `routing.md`, one section per folder. Folders can be projects, clients, teams or topics.
- Signals and their priority: recurring series > attendee domain > title keyword > invite description (or the transcript's topic as a last resort).
- A meeting lives in its best-matching folder. Other strong matches get a cross-link in their `_project.md`.
- **Setup** (once, with approval): the agent proposes folders from recent meetings, and the user approves, renames, merges or rejects them.
- **Unmatched meetings:** if there's a clear project signal, the agent creates a new folder with a *pending* rule, queued in `_pending.md` for review. Otherwise the meeting goes to `_unsorted/`. Automatic folder creation can be turned off.
- **Rule changes** show a preview of the moves and wait for confirmation.

## Interoperability

- **No hard-coded tools.** Sources are found by capability and keywords (`references/providers.md`), so new notetakers or calendars work without code changes.
- **No hard-coded paths, OS or account.** The workspace location is configurable, notifications are chosen per OS, and owner and timezone come from the calendar or config.
- **Graceful degradation:** with no calendar it works from transcripts only; with no notetaker it uses inbox files and placeholders; with no filesystem it produces downloadable notes. A failing source is reported and skipped.
- **Forward-compatible config:** every setting has a default in the template, so older workspaces keep working after updates.
- **Plain formats:** Markdown with YAML front matter and JSON Lines, readable by Obsidian, any editor, or scripts.

## Scale

- `.ledger.jsonl` is the record of what's done, so runs don't have to search every note.
- Each meeting is fully written before the next one starts, so an interrupted run resumes cleanly.
- `max_meetings_per_run` keeps scheduled runs short; backfills continue over several runs.
- `index.md` covers only open actions and the last 30 days. The full history goes in monthly `_log/` files, and only changed months and folders are rewritten.
- Project summaries are updated incrementally from the previous summary plus the new meetings.

## Calls made without the user (change them if wrong)

- Transcript matching window: ±15 minutes from the meeting start, with title similarity as the tie-breaker.
- A matched inbox file is moved into the meeting folder as `transcript.md`.
- Folder names are Title Case; meeting slugs are lowercase, hyphenated ASCII.
- Common personal email domains never count as a company signal.
