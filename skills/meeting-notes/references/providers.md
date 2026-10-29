# Providers: finding calendar and transcript sources

The agent never hard-codes a connector. It looks at the tools available in the current session and matches them by **capability**. Tool names differ between accounts and versions, so match on what a tool does, not on its exact name.

If tools are deferred or hidden behind a search tool, search for the keywords below before deciding a source is missing.

## Calendar source (optional)

Needed capability: **list events in a date range**, with title, start/end, attendees (with email and response status), description, recurring-series id, and an event link.

| Provider | Search keywords |
|---|---|
| Google Calendar | `calendar`, `gcal`, `google calendar`, `list_events` |
| Microsoft 365 / Outlook | `outlook`, `microsoft`, `calendar`, `events` |
| Any other calendar connector | `calendar`, `events`, `schedule` |
| ICS file | `<ws>/_inbox/*.ics`: parse it as a calendar for those dates |

If `calendar` in config names a provider, use it. With `calendar: auto`, use the first one found. If several are connected and config says `auto`, use them all and de-duplicate events with the same title and start time.

The owner's response status may be named `responseStatus`, `response`, `myResponse` or similar. Treat "accepted", "organizer" and "tentative" as attending. If the provider doesn't expose a response status, treat every event the owner is invited to as attending.

## Transcript sources

Tried in the order of `sources` in config. The default is `connectors, inbox`.

### `connectors`: any connected notetaker

Needed capability: **list recordings/notes in a date range** and **get the transcript** of one.

| Provider | Search keywords |
|---|---|
| Granola | `granola`, `meeting notes`, `transcript` |
| Fireflies | `fireflies`, `transcript` |
| Otter | `otter`, `transcript` |
| Fathom | `fathom`, `recording` |
| Zoom | `zoom`, `recording`, `transcript` |
| tl;dv, Read.ai, Fellow, Avoma, Gong, … | the product name, `transcript`, `recording` |

You can also name specific providers in `sources` (e.g. `sources: granola, inbox`) to fix the order or exclude others.

If a notetaker also has its own AI notes or summary, fetch them too as extra context for the note. They don't replace the transcript.

### `inbox`: files in `<ws>/_inbox/`

For anything without a connector: Wispr Flow, voice memos, Zoom/Teams/Meet downloads, or exports from any tool.

Accepted formats: `.md`, `.txt`, `.vtt`, `.srt`, `.json` (an export with a transcript field), `.docx` (read the text). Ignore other files and leave them alone.

Subfolders are fine (e.g. `_inbox/wispr/`, `_inbox/zoom/`); the subfolder name is recorded as the `source`.

The timestamp is taken from, in order:
1. the filename (e.g. `2026-10-29 14-02.txt`, `GMT20261029-140210_Recording.vtt`, `wispr-2026-10-29T14:00.md`),
2. a date/time line or front matter inside the file,
3. the file's modified time (last resort).

In transcript-first mode (no calendar), the title comes from the filename or the file's first heading, and attendees come from speaker labels if there are any.

## When a source fails

- Auth error or expired sign-in: skip the source, say in the summary "<provider> needs you to sign in again", and continue.
- Rate limit or timeout: retry once, then skip the source for this run. The catch-up window will cover it next run.
- Never fall back to scraping websites or asking for passwords.
