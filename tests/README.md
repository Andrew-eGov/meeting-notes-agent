# Tests

All test data is fictional (Acme, Northwind, Project Falcon on 2026-10-28).

## Trigger script (automatic, runs in CI)

```bash
./tests/trigger-test.sh
```

This runs 20 scenarios against `scripts/meeting-notes-trigger.sh` with a fake Claude command: inbox files, due post-meeting checks, locks (held, stale, released after failure), the daily reconcile, Muesli database changes, and the heartbeat.

## End-to-end (local, needs the claude CLI signed in)

```bash
./tests/e2e.sh
```

This replays a mock workday through the real pipeline: watcher script → `claude -p` (headless) → the plugin loaded from this repo → files. No connectors are loaded. The steps:

1. The day's transcripts are in the inbox. A quick run must file everything and pass all 83 checks in `check_mock.py`.
2. Nothing is new. Claude must not start.
3. A late dictation arrives. Only the placeholder note may change.
4. A daily reconcile with nothing new. No file may change, and the lock must be released.

The mock clock is set through `MEETING_NOTES_NOW`, which the watcher passes to the agent as `--now`. A full run takes about 4–5 minutes. Use `--dry-run` to test the harness without Claude.

## Agent runs (manual, since they need an AI agent)

1. Build a mock workspace:
   ```bash
   ./tests/make-workspace.sh inbox /tmp/mt/Meetings     # transcripts as inbox files
   ./tests/make-workspace.sh muesli /tmp/mt2/Meetings   # transcripts from a fake muesli-cli
   ```
   For `muesli`, export the `PATH` and `MUESLI_FAKE_DATA` it prints, so the agent finds the fake CLI.
2. Run the agent unattended with "now" = `2026-10-28T18:05:00Z` and timezone UTC:
   ```text
   /meeting-notes 2026-10-28 --dir /tmp/mt/Meetings
   ```
3. Check the output:
   ```bash
   python3 tests/checks/check_mock.py /tmp/mt/Meetings
   python3 tests/checks/check_muesli.py /tmp/mt2/Meetings "$MUESLI_FAKE_DATA/calls.log"
   ```

### What the agent runs check

- **Inbox:** the calendar filters (declined, solo, private), routing into new pending folders, all five note sections, decisions and owned action items with absolute due dates, the placeholder for the unrecorded meeting, valid ledger JSON Lines, the indexes, and that no trace of the private HR meeting appears anywhere.
- **Muesli:** matching by `calendarEventID` and by time, the dictation fallback when a recording is still processing, transcribing inbox audio, read-only use of `muesli-cli` (checked from its call log), and the private recording never being fetched.

### Further scenarios verified during development

- Re-running reconcile with nothing new changes no files.
- A quick run upgrades only the placeholder once its transcript arrives.
- A `provisional` note (built from dictation) is replaced when Muesli's transcript arrives, but only if its hash shows it wasn't edited.
- A full run on a Google Drive workspace (`drive:<folder id>`) through the Drive connector. The Drive folder was copied back locally and passed the same `check_mock.py`.
