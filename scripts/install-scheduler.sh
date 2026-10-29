#!/usr/bin/env bash
# Install (or remove) the background triggers for the meeting-notes agent.
#
#   install-scheduler.sh --dir <Meetings dir> [--reconcile-at 18:00] [--uninstall]
#
# macOS: two LaunchAgents in ~/Library/LaunchAgents
#   - trigger: every 5 minutes and whenever _inbox/ changes (cheap; starts Claude only when there is work)
#   - reconcile: once a day at --reconcile-at
# Linux: two crontab lines (same behaviour; inbox changes are noticed within 5 minutes)
# Windows: see docs/scheduling.md
set -euo pipefail

ws="${MEETING_NOTES_DIR:-}"
at="18:00"
uninstall=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) ws="$2"; shift ;;
    --reconcile-at) at="$2"; shift ;;
    --uninstall) uninstall=1 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

script="$(cd "$(dirname "$0")" && pwd)/meeting-notes-trigger.sh"
label="com.meeting-notes"
hour=$((10#${at%:*})); minute=$((10#${at#*:}))

if [ "$uninstall" -eq 0 ]; then
  [ -n "$ws" ] || { echo "pass --dir <Meetings dir> or set MEETING_NOTES_DIR" >&2; exit 2; }
  ws="$(cd "$ws" && pwd)"
  [ -f "$ws/config.md" ] || { echo "no workspace at $ws (run /meeting-notes init first)" >&2; exit 1; }
  command -v claude >/dev/null || { echo "the claude CLI must be installed and signed in (run: claude, then /login)" >&2; exit 1; }
  command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
fi

case "$(uname -s)" in
Darwin)
  agents="$HOME/Library/LaunchAgents"
  mkdir -p "$agents"
  for job in trigger reconcile; do
    plist="$agents/$label.$job.plist"
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
    rm -f "$plist"
  done
  if [ "$uninstall" -eq 1 ]; then echo "Removed meeting-notes LaunchAgents."; exit 0; fi

  path_env="$(dirname "$(command -v claude)"):$(dirname "$(command -v jq)"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
  write_plist() { # job, extra args, schedule xml
    cat > "$agents/$label.$1.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label.$1</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$script</string><string>--dir</string><string>$ws</string>$2</array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$path_env</string></dict>
$3
  <key>StandardErrorPath</key><string>$ws/.trigger.err</string>
</dict>
</plist>
EOF
    launchctl bootstrap "gui/$(id -u)" "$agents/$label.$1.plist"
  }
  write_plist trigger "" "  <key>StartInterval</key><integer>300</integer>
  <key>WatchPaths</key><array><string>$ws/_inbox</string></array>
  <key>ThrottleInterval</key><integer>60</integer>"
  write_plist reconcile "<string>--reconcile</string>" "  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer></dict>"
  echo "Installed: quick checks every 5 min + on inbox changes, reconcile daily at $at."
  echo "Logs: $ws/.trigger.log"
  case "$ws" in "$HOME/Desktop"*|"$HOME/Documents"*|"$HOME/Downloads"*)
    echo "Note: $ws is in a protected folder. If runs fail with 'Operation not permitted',"
    echo "give /bin/bash Full Disk Access in System Settings → Privacy & Security." ;;
  esac
  ;;
Linux)
  current="$(crontab -l 2>/dev/null | grep -v '# meeting-notes' || true)"
  if [ "$uninstall" -eq 1 ]; then printf '%s\n' "$current" | crontab -; echo "Removed meeting-notes cron jobs."; exit 0; fi
  {
    printf '%s\n' "$current"
    echo "*/5 * * * * \"$script\" --dir \"$ws\" # meeting-notes"
    echo "$minute $hour * * * \"$script\" --reconcile --dir \"$ws\" # meeting-notes"
  } | crontab -
  echo "Installed cron jobs: quick checks every 5 min, reconcile daily at $at. Logs: $ws/.trigger.log"
  ;;
*)
  echo "Unsupported OS for automatic install. See docs/scheduling.md." >&2; exit 1 ;;
esac
