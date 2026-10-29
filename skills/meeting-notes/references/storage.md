# Storage: where the workspace lives

The workspace (`<ws>`) can be a local folder or a cloud drive folder. The layout and file formats are identical either way; only how files are read and written changes.

| `<ws>` looks like | Backend |
|---|---|
| A normal path (`~/Documents/Meetings`, `./Meetings`) | **local** |
| A path inside a synced cloud folder (`~/Library/CloudStorage/GoogleDrive-…/My Drive/Meetings`, Dropbox, OneDrive) | **local**. The sync app uploads it, so this is the most reliable way to keep notes on Drive |
| `drive:<folder id>` or `drive:My Drive/Meetings` | **drive**: Google Drive through the Drive connector, with no local folder at all |

`MEETING_NOTES_DIR` and `--dir` accept all of these forms.

## Backend: drive

Use this when there's no local filesystem (claude.ai, a cloud routine), or when the user wants the workspace only on Drive. It needs a connected Google Drive tool that can **search** (by parent folder and title), **read/download**, **create files and folders**, **move** (change a file's parent), and **trash**. Find them with the keywords `drive`, `google drive`, `search_files`, `create_file`.

### Resolving the workspace

- `drive:<folder id>` → use that folder.
- `drive:My Drive/Meetings` → start at the root and look up each path segment as a folder with that exact title under the previous one. If the last segment is missing and the mode is Init, create it. In any other mode, stop and say the workspace wasn't found.
- Paths inside the workspace (`Acme/2026-10-28_slug/notes.md`) are resolved the same way, segment by segment. Keep a map of path → id for the rest of the run, so each folder is looked up only once.

### Operations

| Operation | How |
|---|---|
| List a folder | Search for files whose parent is the folder id. Use `title =` for an exact name. Searches normally leave out trashed files; if a result is marked as trashed, skip it |
| Read a file | Download its content as plain text. Use a natural-language "read" tool only for Google Docs or PDFs (e.g. invite attachments) |
| Create a file | Create it with the plain-text content, the content type (`text/markdown` for `.md`, `application/json` for `.json`/`.jsonl`) and **conversion to Google Docs turned off**, so it stays a real `.md`/`.json` file other tools can read |
| Create a folder | Create a file with the folder MIME type (`application/vnd.google-apps.folder`) |
| Empty files | Drive won't create an empty text file. Don't create placeholders: create a file only once you have its first real content (e.g. the ledger with its first line, `_project.md` at the index step) |
| **Replace a file** (index, ledger, `_project.md`, routing, a placeholder note being upgraded) | The connector can't edit a file's content in place. **Create the new version first**, with the same title in the same folder; once that succeeds, **trash the old version**. If the create fails, leave the old file alone. Never have two live files with the same title in a folder: if you find duplicates, keep the newest and trash the others |
| Move (Review mode, inbox → meeting folder) | Change the file's parent folder. Don't copy and delete |
| Delete | Trash only, never permanent deletion. The user can restore anything from the Drive bin |

For a matched inbox file, follow the same rule as local: write `transcript.md` in the meeting folder, then trash the inbox file.

### Ledger on Drive

Every rewrite costs a create plus a trash, and leaves the old version in the Drive bin. Keep rewrites to a minimum:
- `.ledger.jsonl`: **once per meeting**, after that meeting's files are written, so an interrupted run can resume.
- `routing.md` and `_pending.md`: **once, at the end of the run**, with every change from the run. If a run is interrupted before then, the next run notices meeting folders that have no rule and adds pending rules for them (see the routing reference).
- Generated files (`index.md`, `_log`, `_project.md`, `.schedule.json`): only when their content changes, not counting timestamp lines.

Add `"drive_id": "<meeting folder id>"` to each ledger line, so later runs can open the meeting folder directly.

### Lock on Drive

There's no lock folder on Drive, so use a file instead:

- Before a Quick or Run, look for `.run.lock` in `<ws>`.
- If it exists and was modified less than 30 minutes ago, stop ("another run is in progress"). Measure its age on Drive's clock: compare its `modifiedTime` with the `createdTime` Drive returns for a file you've just created (or with the current time, if you have no newer Drive timestamp).
- Otherwise create it (as `text/plain`, containing the start time), replacing a stale one, and trash it when the run ends, even if the run failed.

### Triggers with a Drive workspace

- **Drive synced to the computer** (Google Drive for desktop): use the normal trigger script with the local synced path. Everything works, including instant inbox triggers.
- **Drive-only**: the trigger script can't watch Drive. Schedule `quick` every 30 minutes and `reconcile` daily instead, as Claude desktop scheduled tasks or cloud routines. Cloud routines can reach the Drive connector, so this setup needs no computer at all.

### Privacy

Workspace files keep their folder's sharing. Never change permissions, never share files, and never create files outside `<ws>`.
