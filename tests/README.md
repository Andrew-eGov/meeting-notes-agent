# Tests

All test data is fictional (Acme, Northwind, Project Falcon on 2026-10-28).

## Trigger script (automatic, runs in CI)

```bash
./tests/trigger-test.sh
```

This runs 20 scenarios against `scripts/meeting-notes-trigger.sh` with a fake Claude command: inbox files, due post-meeting checks, locks (held, stale, released after failure), the daily reconcile, Muesli database changes, and the heartbeat.

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
