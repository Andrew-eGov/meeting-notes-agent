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
| ICS file | `<ws>/_inbox/*.ics`: parse it as a calendar for those dates. It's a calendar, not a transcript: never move or delete it, and don't count it as a leftover inbox file. Expand `RRULE` recurrences for the days in scope. |

If `calendar` in config names a provider, use it. With `calendar: auto`, use the first one found. If several are connected and config says `auto`, use them all and de-duplicate events with the same title and start time.

The owner's response status may be named `responseStatus`, `response`, `myResponse` or similar. Treat "accepted", "organizer" and "tentative" as attending. If the provider doesn't expose a response status, treat every event the owner is invited to as attending.

## Transcript sources

Tried in the order of `sources` in config. The default is `connectors, local, attachments, inbox`.

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

`source` = the provider name in lowercase (`granola`, `fireflies`, …).

### `local`: notetaker apps with a local command-line tool

Some notetakers, often open-source and local-first ones, have no cloud connector. Instead they ship a command-line tool on the user's computer. This needs a shell. In a shell-less environment (claude.ai, cloud routines), skip this source silently.

#### Muesli (macOS, open source: github.com/Muesli-HQ/muesli)

Local meeting transcription and dictation, an alternative to Granola and Wispr Flow. Its bundled `muesli-cli` is the API: data commands print a JSON envelope to stdout (`{"ok": true, "data": …}` or `{"ok": false, "error": {code, message, fix}}`). Anything on stderr is informational.

**Find the binary**, using the first that works, then confirm it with `<bin> info` (`ok: true`):
1. `command -v muesli-cli`
2. `/Applications/Muesli.app/Contents/MacOS/muesli-cli`
3. `~/Applications/Muesli.app/Contents/MacOS/muesli-cli`

If none works, Muesli isn't installed: skip it silently. If the commands you need aren't recognised, run `<bin> spec` to see the installed version's command tree.

| Need | Command | Use |
|---|---|---|
| Meetings in range | `muesli-cli meetings list --limit 200` | Rows have `id`, `title`, `startTime`, `durationSeconds`, `wordCount`, `notesState`. There's no date filter, so keep the rows whose `startTime` falls in the days in scope. If every row is in range, raise `--limit` |
| One meeting | `muesli-cli meetings get <id>` | `rawTranscript` → `transcript.md`. `formattedNotes` is extra context only. `calendarEventID` links it to the calendar |
| Dictations | `muesli-cli dictations list --limit 200`, then `dictations get <id>` | `rawText`, `timestamp`, `durationSeconds`. These are Wispr-style dictated notes |
| Audio file → text | `muesli-cli transcribe <file> --format json` | `data.transcript`. Accepts `.mp3`, `.mp4`, `.m4a`, `.wav` (see `inbox` below) |

**Matching:**
- A Muesli meeting whose `calendarEventID` equals the calendar event's id (or its series id plus the same start time) matches that event exactly, with no time window needed.
- Otherwise use the normal time-window match on `startTime`.
- List rows (`wordCount`, `notesState`) can lag behind while Muesli is processing, so always `meetings get` a candidate in the time window rather than skipping it based on its list row.
- Use a meeting only if its `rawTranscript` isn't empty. If it's empty, it's still recording or processing: treat it as not found yet, and the post-meeting checks will try again.
- **Dictations** are used only when no meeting transcript matched. Join the dictations whose `timestamp` falls inside the meeting window, in time order, treat them as dictated notes (say so in the TL;DR), and use `source: muesli:dictation`.

**Transcript-first mode:** each Muesli meeting in range is a meeting, with `meeting_id: muesli:<id>`.

`source` = `muesli`.

**Read-only:** never run `update-notes`, `transcribe --save-meeting`, or anything else that writes to Muesli. Never read or copy its audio files (`micAudioPath`, `systemAudioPath`). If a command fails with `ok: false`, report `error.message` in the summary and skip Muesli for this run.

#### Other local tools

Any notetaker CLI with the same capabilities (list meetings in a range, get a transcript, ideally with a calendar event id) can be added here following the Muesli pattern.

### `attachments`: documents attached to the calendar invite

Many meeting tools attach the transcript or notes to the invite after the meeting. Examples: Google Meet's "Transcript" and "Notes by Gemini" docs, Teams' recap, Zoom's AI summary link, or a notetaker that posts a link into the description.

1. From the calendar event, read its **attachments** (file id/URL, title, MIME type) and any links in the **description** that point to a document.
2. Use the attachment if its title or URL looks like a transcript or meeting notes (`transcript`, `notes`, `recap`, `summary`, `Notes by Gemini`), or if it was added after the meeting started.
3. Fetch its text with a connected document tool that can read it: Google Drive for Google Docs, OneDrive/SharePoint for Microsoft files (search keywords `drive`, `docs`, `onedrive`, `sharepoint`, `read file`). If no such tool exists, or access is denied, skip this source for the meeting.
4. A verbatim transcript is better than a notes doc. If both are attached, use the transcript as `transcript.md` and the notes doc as extra context.

`source` = `attachment:<provider>` (e.g. `attachment:google-meet`). Matching is by the event itself, so no time window is needed. Never change the attachment or its sharing settings.

### `inbox`: files in `<ws>/_inbox/`

For anything without a connector: Wispr Flow, voice memos, Zoom/Teams/Meet downloads, or exports from any tool.

Accepted formats: `.md`, `.txt`, `.vtt`, `.srt`, `.json` (an export with a transcript field), `.docx` (read the text). Audio files (`.m4a`, `.mp3`, `.mp4`, `.wav`) are accepted when a local transcription tool is available (e.g. `muesli-cli transcribe`; see `local` above). The transcription goes in `transcript.md`, and the audio file itself moves into the meeting folder rather than being deleted. Ignore other files and leave them alone.

Subfolders are fine (e.g. `_inbox/wispr/`, `_inbox/zoom/`). `source` = `inbox:<subfolder>` (e.g. `inbox:wispr`), or `inbox` for files at the top level, so files are never confused with a connector of the same name.

The timestamp is taken from, in order:
1. the filename (e.g. `2026-10-29 14-02.txt`, `GMT20261029-140210_Recording.vtt`, `wispr-2026-10-29T14-00.md`). Accept `-`, `:`, `.` or nothing between hours and minutes. A filename time is in the workspace `timezone` unless it says otherwise (`GMT…` or `Z` means UTC),
2. a date/time line or front matter inside the file,
3. the file's modified time (last resort).

In transcript-first mode (no calendar), the title comes from the filename or the file's first heading, and attendees come from speaker labels if there are any.

## When a source fails

- Auth error or expired sign-in: skip the source, say in the summary "<provider> needs you to sign in again", and continue.
- Rate limit or timeout: retry once, then skip the source for this run. The catch-up window will cover it next run.
- Never fall back to scraping websites or asking for passwords.
