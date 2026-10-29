#!/usr/bin/env bash
# Tests for scripts/meeting-notes-trigger.sh with a fake Claude command. Runs on macOS and Linux (CI).
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ws="$tmp/Meetings"; mkdir -p "$ws/_inbox" "$tmp/muesli"; : > "$ws/config.md"; : > "$tmp/calls"
printf '#!/bin/bash\necho "$1" >> "%s/calls"\n' "$tmp" > "$tmp/fake-claude"; chmod +x "$tmp/fake-claude"
export MEETING_NOTES_CMD="$tmp/fake-claude" MEETING_NOTES_HEARTBEAT_MIN=0 MUESLI_DB="$tmp/muesli/muesli.db"

stamp() { if date -v-1M >/dev/null 2>&1; then date -v-"$1"M +%Y%m%d%H%M.%S; else date -d "-$1 min" +%Y%m%d%H%M.%S; fi; }
pass=0; fail=0
expect() { # name, expected (run|skip), [extra args]
  local name="$1" want="$2"; shift 2
  local before after got; before=$(wc -l < "$tmp/calls")
  "$root/scripts/meeting-notes-trigger.sh" --dir "$ws" "$@" >/dev/null 2>&1
  after=$(wc -l < "$tmp/calls"); [ "$after" -gt "$before" ] && got=run || got=skip
  if [ "$got" = "$want" ]; then pass=$((pass+1)); echo "PASS  $name"; else fail=$((fail+1)); echo "FAIL  $name (wanted $want, got $got)"; fi
}

expect "nothing to do" skip
echo a > "$ws/_inbox/a.txt";                         expect "new inbox file" run
grep -q -- "--locked" "$tmp/calls" && { pass=$((pass+1)); echo "PASS  mode passed with --locked"; } || { fail=$((fail+1)); echo "FAIL  mode passed with --locked"; }
expect "same file, next tick" skip
sleep 1; echo b > "$ws/_inbox/b.txt";                expect "another new file" run
last=$(cat "$ws/.trigger-state"); now=$(date +%s)
printf '{"checks":[{"meeting_id":"x","at_epoch":%s}]}' "$((now-1))" > "$ws/.schedule.json"
[ $((now-1)) -gt "$last" ] || sleep 2
printf '{"checks":[{"meeting_id":"x","at_epoch":%s}]}' "$(( $(date +%s) - 1 ))" > "$ws/.schedule.json"; expect "post-meeting check due" run
expect "same check, next tick" skip
printf '{"checks":[{"meeting_id":"y","at_epoch":%s}]}' "$(( $(date +%s) + 600 ))" > "$ws/.schedule.json"; expect "check not due yet" skip
sleep 1; mkdir "$ws/.run.lock"; echo c > "$ws/_inbox/c.txt"; expect "lock held by another run" skip
rmdir "$ws/.run.lock";                               expect "lock released, file picked up" run
expect "daily reconcile always runs" run --reconcile
sleep 1; echo d > "$ws/_inbox/d.txt"
MEETING_NOTES_CMD=false "$root/scripts/meeting-notes-trigger.sh" --dir "$ws" >/dev/null 2>&1
[ ! -d "$ws/.run.lock" ] && { pass=$((pass+1)); echo "PASS  failed run releases the lock"; } || { fail=$((fail+1)); echo "FAIL  failed run releases the lock"; }
expect "failed work retried next tick" run
mkdir "$ws/.run.lock"; touch -t "$(stamp 120)" "$ws/.run.lock"; echo e > "$ws/_inbox/e.txt"; expect "stale lock cleared" run
# Muesli: the last run was an hour ago, then Muesli saves a recording (inbox emptied so only Muesli can trigger)
rm -f "$ws/_inbox/"*
echo $(( $(date +%s) - 3600 )) > "$ws/.trigger-state"; touch -t "$(stamp 60)" "$ws/.trigger-state"
: > "$MUESLI_DB"; : > "$MUESLI_DB-wal";              expect "Muesli writing right now" skip
touch -t "$(stamp 10)" "$MUESLI_DB" "$MUESLI_DB-wal"; expect "Muesli quiet for 10 min" run
expect "same Muesli data, next tick" skip
touch -t "$(stamp 10)" "$MUESLI_DB"; touch "$MUESLI_DB-wal"; expect "Muesli WAL still being written" skip
echo 0 > "$ws/.trigger-state"; touch -t 202601010000 "$ws/.trigger-state"
MEETING_NOTES_HEARTBEAT_MIN=1 MEETING_NOTES_HOURS=0-24 expect "heartbeat after quiet period" run
echo 0 > "$ws/.trigger-state"; touch -t 202601010000 "$ws/.trigger-state"; rm -f "$MUESLI_DB" "$MUESLI_DB-wal"; rm -f "$ws/_inbox/"*
MEETING_NOTES_HEARTBEAT_MIN=1 MEETING_NOTES_HOURS=0-0 expect "no heartbeat outside working hours" skip

echo; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
