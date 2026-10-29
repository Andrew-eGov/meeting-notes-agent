# Ledger and index files

Generated files are designed to stay fast with thousands of meetings: the agent uses the ledger instead of searching through every note, and each run touches only what changed.

## .ledger.jsonl (machine state, source of truth for "done")

One JSON object per line, one line per meeting. To update a meeting, rewrite its line (read the file, replace the line with the same `meeting_id`, then write it back). Never keep two lines for the same id.

```json
{"meeting_id":"abc123","date":"2026-10-29","start":"14:00","title":"Acme weekly sync","folder":"Acme","also_in":["Hiring"],"path":"Acme/2026-10-29_acme-weekly-sync","status":"complete","series_id":"abc","source":"granola","notes_sha256":"9f2c…","open_actions":2,"updated":"2026-10-29T18:04:00Z"}
```

- `status`: `complete` | `provisional` | `placeholder`
- `notes_sha256`: SHA-256 of `notes.md` as the agent wrote it (to detect user edits)
- `series_id`: optional, for recurring meetings
- `path`: relative to `<ws>`
- Sensitive meetings never get a ledger line.

If the ledger is missing or damaged, rebuild it by reading the front matter of every `notes.md` under `<ws>`. Do this once, then go back to using the ledger.

## index.md (overview, kept short)

Rebuilt each run from the ledger plus the notes that have open action items. It covers **all open action items** and **the last 30 days** of meetings; older meetings are listed in `_log/`.

```markdown
# Meetings

_Updated 2026-10-29 18:04 by meeting-notes. Generated file: don't edit it by hand. Tick action items in each meeting's notes.md._

## Open action items

### Mine
- [ ] Send revised proposal (due Fri Oct 31) — [Acme weekly sync, Oct 29](Acme/2026-10-29_acme-weekly-sync/notes.md)

### Others
- [ ] @Priya Shah — Book design review — [Acme weekly sync, Oct 29](Acme/2026-10-29_acme-weekly-sync/notes.md)

## Last 30 days

### 2026-10-29
- [Acme weekly sync](Acme/2026-10-29_acme-weekly-sync/notes.md) · Acme · 14:00
- [Coffee with Jo](_unsorted/2026-10-29_coffee-with-jo/notes.md) · unsorted · 16:00 · _no transcript yet_

## Older
- [2026-09](_log/2026-09.md) · [2026-08](_log/2026-08.md)
```

Leave out the "Older" section when there are no older months.

- "Mine" = items whose owner matches `owner_name` in config; they're shown without the `@owner` prefix. Everything else goes under "Others", including `@unassigned`.
- Order: days newest first; meetings within a day by start time; action items by meeting date (oldest first, since they've been open longest).
- Paths with spaces are written with `%20` in links (`Project%20Falcon/…`).
- An item is open while its checkbox is `- [ ]`. To gather the open items, read only the notes whose ledger line has `open_actions > 0`, and refresh that count while reading.

## _log/YYYY-MM.md (full history, one file per month)

Rewrite only the months that had meetings added, upgraded or moved in this run.

Newest first.

```markdown
# Meetings — October 2026

- 2026-10-29 14:00 · [Acme weekly sync](../Acme/2026-10-29_acme-weekly-sync/notes.md) · Acme
- 2026-10-28 10:00 · [Hiring plan review](../Hiring/2026-10-28_hiring-plan-review/notes.md) · Hiring
```

## <Folder>/_project.md

Rewrite only for folders that got a new, upgraded or moved meeting (or a cross-link) in this run.

```markdown
# Acme

_Rule status: active · Updated 2026-10-29 18:04_   ← always fill in the date and time of this run

## Where things stand
3–5 sentences synthesized from this folder's most recent meetings (and linked ones): current status, latest decisions, what's next. Base it on the notes, not on guesses.

## Open action items
- [ ] @Sam Lee — Send revised proposal (due Fri Oct 31) — [Oct 29](2026-10-29_acme-weekly-sync/notes.md)

## Meetings
- 2026-10-29 — [Acme weekly sync](2026-10-29_acme-weekly-sync/notes.md)
- 2026-10-22 — [Acme weekly sync](2026-10-22_acme-weekly-sync/notes.md)

## Linked from other folders
- 2026-10-27 — [Hiring plan review](../Hiring/2026-10-27_hiring-plan-review/notes.md) (home: Hiring)
```

To write "Where things stand", read the previous summary plus the notes from this run only, rather than re-reading the folder's whole history.

## .schedule.json (read by the trigger script)

Rewritten at the end of every Quick and Run. It lists when to look for transcripts of today's and tomorrow's meetings that don't have a complete note yet: one check per `after_meeting_checks` offset after each meeting's end. Leave out checks more than 24 hours old. It holds ids and times only, never titles or attendees.

```json
{
  "generated": "2026-10-29T18:04:00Z",
  "checks": [
    {"meeting_id": "abc123", "at": "2026-10-30T10:55:00Z", "at_epoch": 1793357700},
    {"meeting_id": "abc123", "at": "2026-10-30T11:30:00Z", "at_epoch": 1793359800}
  ]
}
```

`at_epoch` is Unix seconds (UTC). Work it out exactly (e.g. with `date -u -d … +%s` on Linux or `date -u -j -f … +%s` on macOS) rather than estimating it.
