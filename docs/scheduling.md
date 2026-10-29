# Running it automatically

The agent runs in four ways:

| Trigger | What runs | When |
|---|---|---|
| **A meeting ends** | `quick` | 10 min, 45 min and 3 h after each meeting's end (configurable), until its transcript is found |
| **A transcript arrives** | `quick` | Instantly, when a file lands in `_inbox/` (Wispr, Zoom downloads, …) on macOS; within 5 minutes elsewhere. Muesli recordings are picked up within 5 minutes of Muesli finishing |
| **Daily reconcile** | `reconcile` | Every day at 6 pm (configurable): catches anything missed, ad-hoc meetings, late transcripts, and the last 7 days |
| **On demand** | either | `/meeting-notes`, or ask Claude in any session |

Calendars and notetakers can't push events to your machine, so a small **watcher script** (`scripts/meeting-notes-trigger.sh`) checks every 5 minutes. It starts Claude only when there's work to do: a post-meeting check came due, a file arrived in `_inbox/`, or (during working hours) two hours passed with no run, to pick up invites added during the day. Otherwise it exits in milliseconds and uses no Claude.

`quick` runs only look at meetings that just ended and at new transcripts, so they stay short. The 6 pm `reconcile` does the full catch-up.

Runs use your local `Meetings/` folder, so they happen on your machine. Cloud schedulers can't see that folder.

## Before you start

1. Install the [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) and sign in: run `claude`, then `/login`. Background runs use this sign-in, so if it expires they fail until you sign in again (they're retried automatically, and the log says so).
2. Install `jq` (preinstalled on recent macOS; `sudo apt install jq` on Debian/Ubuntu).
3. Create the workspace (`/meeting-notes init`) and connect your calendar and notetaker if you have them.

## macOS and Linux (recommended)

From your clone of this repo:

```bash
./scripts/install-scheduler.sh --dir ~/Documents/Meetings --reconcile-at 18:00
```

- **macOS** installs two LaunchAgents: the watcher (every 5 min, and instantly when `_inbox/` changes) and the daily reconcile.
- **Linux** adds two crontab lines (the watcher every 5 min, and the reconcile).

To remove them:

```bash
./scripts/install-scheduler.sh --uninstall
```

Logs are written to `Meetings/.trigger.log`.

If the workspace is in Desktop, Documents or Downloads on macOS and runs fail with "Operation not permitted", give `/bin/bash` **Full Disk Access** (System Settings → Privacy & Security), or move the workspace elsewhere.

### Tuning

Set these as environment variables (on macOS, add them to the plist's `EnvironmentVariables`):

| Variable | Default | Meaning |
|---|---|---|
| `MEETING_NOTES_HEARTBEAT_MIN` | `120` | Run a quick check at least this often during working hours; `0` turns it off |
| `MEETING_NOTES_HOURS` | `8-19` | Working hours for the heartbeat |
| `MEETING_NOTES_TIMEOUT_MIN` | `30` | Maximum length of a single run |
| `MEETING_NOTES_CMD` | `claude -p …` | A custom command, e.g. another agent CLI. The mode (`quick`/`reconcile`) is appended |

The post-meeting check times are set in `Meetings/config.md` (`after_meeting_checks`).

## Windows

Use WSL or Git Bash to run the watcher script, scheduled with Task Scheduler:

```powershell
schtasks /Create /TN "Meeting notes trigger" /SC MINUTE /MO 5 /TR "bash -lc '~/meeting-notes-agent/scripts/meeting-notes-trigger.sh --dir ~/Meetings'"
```

```powershell
schtasks /Create /TN "Meeting notes reconcile" /SC DAILY /ST 18:00 /TR "bash -lc '~/meeting-notes-agent/scripts/meeting-notes-trigger.sh --reconcile --dir ~/Meetings'"
```

## Claude desktop app only (no scripts)

If you'd rather not install anything, ask Claude in a Code session opened in the folder that contains `Meetings/`:

> Create two scheduled tasks: run `/meeting-notes quick` every 30 minutes from 8am to 7pm, and `/meeting-notes reconcile` every day at 6pm.

This is simpler but uses more Claude usage, because every check starts Claude even when there's nothing to do. Tasks only run while the app is open.

## Checking it works

- `Meetings/.trigger.log` shows each start and why it started ("2 new inbox file(s)", "1 meeting check(s) due", "daily reconcile").
- `/meeting-notes status` shows the last run, the next scheduled checks, and anything pending.
