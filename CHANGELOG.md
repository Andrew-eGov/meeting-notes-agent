# Changelog

## 0.2.1 — 2026-10-29

- Fix: the agent now always works out "now" first (`--now`, then `MEETING_NOTES_NOW`, then the system clock), and the watcher passes `--now` explicitly, so tests and replays of a past day behave correctly.
- Fix: background runs may use `shasum`/`sha256sum`, `jq`, `cp`, `touch` and `rmdir`, which edit detection for provisional notes and lock handling need.
- New `tests/e2e.sh`: replays a mock workday through the real watcher → `claude` CLI → plugin pipeline, with output checks after each step (`--dry-run` tests the harness without Claude).

## 0.2.0 — 2026-10-29

- Event-driven runs: a watcher script (`scripts/meeting-notes-trigger.sh`) starts a `quick` run after each meeting ends (10/45/180 min) and as soon as a file lands in `_inbox/`, plus a daily `reconcile` at 6 pm. It starts Claude only when there is work. `scripts/install-scheduler.sh` sets it up on macOS (LaunchAgents) and Linux (cron).
- Google Drive workspaces: `--dir drive:<folder>` runs entirely through the Google Drive connector. Synced Drive/Dropbox/OneDrive folders work as local paths.
- New source type `local` for notetakers with a command-line tool, starting with Muesli (open source): meetings matched by calendar event id, dictations as a fallback, inbox audio transcribed with `muesli-cli`, strictly read-only. The trigger script also notices when Muesli saves something new.
- `provisional` notes: notes built from dictation or a notes document are upgraded automatically when the verbatim transcript arrives, unless you've edited them (detected by `notes_sha256` in the ledger).
- New transcript source: documents attached to the calendar invite (Google Meet transcripts, Notes by Gemini, Teams recaps).
- Per-occurrence ids for recurring meetings, reserved transcripts for private meetings, relative due dates resolved from the meeting date, cross-link pass, `inbox:<subfolder>` source names, run lock.

## 0.1.0 — 2026-10-29

- First release: calendar-first or transcript-first processing, any notetaker connector or inbox files, project routing with one-time setup and pending folders, ledger, monthly logs, and cross-platform notifications.
