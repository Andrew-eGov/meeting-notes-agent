# Routing

How a meeting is assigned to a folder under `<ws>/`. Folders can be projects, clients, teams or topics; treat them all the same.

## routing.md format

```markdown
## Acme
- status: active                # active | pending
- series: "Acme weekly sync"    # recurring event titles or series ids, comma-separated
- domains: acme.com             # attendee email domains
- title: Acme, Project Falcon   # title keywords
- description: Falcon launch    # keywords in the invite description
- notes: Client work for Acme Corp
```

Any signal line can be missing. Matching is case-insensitive. Title and description keywords match whole words or phrases. Folder names are the `##` headings and must be valid folder names: no `/ \ : * ? " < > |`.

## Matching a meeting

Each folder gets the strength of its strongest matching signal:

| Signal | Strength |
|---|---|
| The meeting belongs to a listed recurring series | 4 |
| An attendee (other than the owner) has a listed domain | 3 |
| The title contains a listed keyword | 2 |
| The invite description contains a listed keyword | 1 |

1. **Home** = the folder with the highest strength. Break ties by the number of matching signals, then active over pending, then the folder with the most recent meeting.
2. **also_in** = every other folder with strength ≥ 2. A match on the description alone doesn't create a cross-link.
3. **No folder matched** → see "No match" below.

These never count as domain signals: the owner's own domain, the domains listed under `ignore_domains` in config, and common personal domains (gmail.com, googlemail.com, outlook.com, hotmail.com, live.com, icloud.com, me.com, yahoo.com, proton.me, protonmail.com).

## No match: new folder or _unsorted

Create a **new folder with a pending rule** only when there's a clear signal:

- an external attendee domain that isn't in any rule (folder name = the company name from the domain, e.g. `acme.com` → `Acme`), or
- a clear project or client name in the title or description (e.g. "Project Falcon kickoff" → `Project Falcon`), or
- (only if neither of the above) the transcript is clearly about one named project or client.

If `auto_create_folders: false` in config, don't create folders: send the meeting to `_unsorted/` and add a suggestion to `_pending.md` instead.

Before creating a folder, check for a near-duplicate (same name ignoring case or spacing, singular/plural, or an obvious abbreviation). If one exists, add the new signal to that folder's rule instead, and note it in `_pending.md` for review.

When creating a folder:
1. Make the folder and an empty `_project.md`.
2. Append a rule with `status: pending` and only the signal that triggered it.
3. Add a line to `_pending.md`:
   ```markdown
   - [ ] New folder **Acme** (pending rule: domains: acme.com). Created 2026-10-29 from "Intro call with Acme"
   ```
4. Set `routing: pending-rule` in the note's front matter.

Otherwise (one-off coffee chats, ad-hoc 1:1s, vague titles, only internal or personal attendees, not part of a series) → `_unsorted/`, with `routing: unsorted`.

## Proposing rules (Setup mode)

From the meetings in the setup period:

1. **Recurring series** that appear 2+ times → one folder each, unless several clearly belong to the same project (then merge them).
2. **External domains** with 2+ meetings → one folder per company, unless a series folder already covers them.
3. **Title keywords** that repeat across 2+ meetings and aren't generic ("sync", "weekly", "1:1", "meeting", "call", "catch up", "standup", "check-in") → candidate folders.
4. Merge candidates that clearly overlap. Aim for a short list (usually 3–12 folders); it's fine for many one-offs to stay unsorted.
5. Never use sensitive meetings when proposing rules.

## Moving meetings (Review mode only, after the user confirms)

1. Move the `YYYY-MM-DD_slug/` folder to the new parent folder.
2. Update `folder:` and `also_in:` in its `notes.md` front matter. Change only the front matter, never the body.
3. Update the meeting's ledger line (`folder`, `path`).
4. Update both folders' `_project.md`, any cross-links, `index.md` and the affected `_log/YYYY-MM.md`.
