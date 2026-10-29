#!/usr/bin/env bash
# Cheap watcher for the meeting-notes agent. Run it every few minutes and on changes to _inbox/.
# It starts Claude only when there is work: a meeting check is due, a file landed in _inbox/,
# or the heartbeat interval has passed. Otherwise it exits without using Claude.
#
#   meeting-notes-trigger.sh [--reconcile] [--dir <Meetings dir>]
#
# Environment:
#   MEETING_NOTES_DIR            workspace (default: ./Meetings)
#   MEETING_NOTES_CMD            shell command that runs Claude; the mode ("quick --locked" or "reconcile --locked") is appended
#                                (default: claude -p with the plugin command, see below)
#   MEETING_NOTES_HEARTBEAT_MIN  run a quick check at least this often during the day (default 120, 0 = off)
#   MEETING_NOTES_HOURS          hours when heartbeat runs may happen, "start-end" (default 8-19)
#   MEETING_NOTES_TIMEOUT_MIN    give up on a single run after this long (default 30)
#   MUESLI_DB                    Muesli database to watch (default: ~/Library/Application Support/Muesli/muesli.db)
set -euo pipefail

mode=quick
ws="${MEETING_NOTES_DIR:-$PWD/Meetings}"
while [ $# -gt 0 ]; do
  case "$1" in
    --reconcile) mode=reconcile ;;
    --dir) ws="$2"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

heartbeat_min="${MEETING_NOTES_HEARTBEAT_MIN:-120}"
hours="${MEETING_NOTES_HOURS:-8-19}"
timeout_min="${MEETING_NOTES_TIMEOUT_MIN:-30}"
allowed_tools='Read Write Edit Glob Grep Bash(mkdir:*) Bash(mv:*) Bash(rm:*) Bash(ls:*) Bash(cat:*) Bash(find:*) Bash(date:*) Bash(stat:*) Bash(osascript:*) Bash(notify-send:*) Bash(muesli-cli:*) Bash(/Applications/Muesli.app/Contents/MacOS/muesli-cli:*) mcp__*'

log="$ws/.trigger.log"
state="$ws/.trigger-state"   # mtime and content = start time of the last successful run
start="$ws/.trigger-start"
lock="$ws/.run.lock"
now=$(date +%s)

say() { echo "$(date '+%F %T') [$mode] $*" >> "$log"; }
mtime() { if stat --version >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1"; fi; }

[ -f "$ws/config.md" ] || { echo "no workspace at $ws (run /meeting-notes init first)" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

# One run at a time. A lock older than the timeout is from a crashed run and is cleared.
if ! mkdir "$lock" 2>/dev/null; then
  lock_age=$(( now - $(mtime "$lock") ))
  if [ "$lock_age" -lt $(( timeout_min * 60 )) ]; then exit 0; fi
  say "clearing stale lock (${lock_age}s old)"
  rmdir "$lock" && mkdir "$lock" || exit 0
fi
trap 'rmdir "$lock" 2>/dev/null || true' EXIT

last_run=0
[ -f "$state" ] && last_run=$(cat "$state")

reasons=()
if [ "$mode" = quick ]; then
  # 1. A post-meeting check came due since the last run (.schedule.json is written by the agent)
  if [ -f "$ws/.schedule.json" ]; then
    due=$(jq --argjson last "$last_run" --argjson now "$now" \
      '[.checks[]? | select(.at_epoch > $last and .at_epoch <= $now)] | length' "$ws/.schedule.json" 2>/dev/null || echo 0)
    [ "$due" -gt 0 ] && reasons+=("$due meeting check(s) due")
  fi
  # 2. New or changed files in the inbox
  if [ -d "$ws/_inbox" ]; then
    if [ -f "$state" ]; then newer=(-newer "$state"); else newer=(); fi
    new_files=$(find "$ws/_inbox" -type f ! -name '.*' ${newer[@]+"${newer[@]}"} | wc -l | tr -d ' ')
    [ "$new_files" -gt 0 ] && reasons+=("$new_files new inbox file(s)")
  fi
  # 3. Muesli saved something new (database changed since the last run and has been quiet for 5 minutes,
  #    so a recording in progress doesn't trigger a run on every tick)
  muesli_db="${MUESLI_DB:-$HOME/Library/Application Support/Muesli/muesli.db}"
  if [ -f "$muesli_db" ]; then
    db_mtime=$(mtime "$muesli_db")
    [ -f "$muesli_db-wal" ] && wal_mtime=$(mtime "$muesli_db-wal") && [ "$wal_mtime" -gt "$db_mtime" ] && db_mtime=$wal_mtime
    if [ "$db_mtime" -gt "$last_run" ] && [ $(( now - db_mtime )) -ge 300 ]; then
      reasons+=("Muesli has new data")
    fi
  fi
  # 4. Heartbeat during working hours, to catch invites added during the day
  hour=$((10#$(date +%H)))
  if [ "$heartbeat_min" -gt 0 ] && [ "$hour" -ge "${hours%-*}" ] && [ "$hour" -lt "${hours#*-}" ] \
     && [ $(( now - last_run )) -ge $(( heartbeat_min * 60 )) ]; then
    reasons+=("heartbeat")
  fi
  [ ${#reasons[@]} -eq 0 ] && exit 0
else
  reasons+=("daily reconcile")
fi

say "starting: ${reasons[*]}"
# Stamp the start time now, so files that arrive during the run are picked up next time
echo "$now" > "$start"
cd "$(dirname "$ws")"
if [ -n "${MEETING_NOTES_CMD:-}" ]; then
  # Run through a shell so quoting in the custom command works; the mode is passed as "$1"
  run=(bash -c "$MEETING_NOTES_CMD \"\$1\"" meeting-notes "$mode --locked")
else
  # shellcheck disable=SC2086
  run=(claude -p "/meeting-notes:meeting-notes $mode --locked --dir $ws" --permission-mode acceptEdits --allowedTools $allowed_tools)
fi

if command -v timeout >/dev/null; then run=(timeout "$(( timeout_min * 60 ))" "${run[@]}"); fi
status=0
"${run[@]}" >> "$log" 2>&1 || status=$?
if [ "$status" -eq 0 ]; then
  mv "$start" "$state"
  say "finished"
else
  rm -f "$start"
  say "failed with exit code $status (will retry on the next tick)"
  exit "$status"
fi
