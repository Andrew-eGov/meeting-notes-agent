#!/usr/bin/env bash
# End-to-end test on a mock workday: watcher script → claude CLI (headless) → plugin → files.
#
#   tests/e2e.sh [--dir <work dir>] [--dry-run]
#
# Needs: the claude CLI, signed in (run `claude`, then /login), plus jq and python3.
# --dry-run swaps Claude for a stub, to test the harness and the watcher's decisions without signing in.
# Uses the plugin straight from this repo (--plugin-dir) with no MCP connectors (--strict-mcp-config).
# All meeting data is fictional. Each Claude run takes a few minutes.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) work="$2"; shift ;;
    --dry-run) dry=1 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
work="${work:-$(mktemp -d)/e2e}"
ws="$work/Meetings"
mkdir -p "$work"
"$root/tests/make-workspace.sh" inbox "$ws" >/dev/null || exit 1

# The watcher calls this with the mode ("quick --locked" or "reconcile --locked") as $1
if [ "$dry" -eq 1 ]; then
  printf '#!/bin/bash\necho "stub claude: $1" >> "%s/claude-calls.log"\n' "$work" > "$work/run-claude.sh"
else
  command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }
  cat > "$work/run-claude.sh" <<EOF
#!/bin/bash
echo "claude: \$1 (MEETING_NOTES_NOW=\$MEETING_NOTES_NOW)" >> "$work/claude-calls.log"
exec claude -p "/meeting-notes:meeting-notes \$1 --dir $ws" \\
  --plugin-dir "$root" --strict-mcp-config --no-session-persistence \\
  --permission-mode acceptEdits \\
  --allowedTools Read Write Edit Glob Grep "Bash(mkdir:*)" "Bash(mv:*)" "Bash(rm:*)" "Bash(ls:*)" "Bash(cat:*)" \\
    "Bash(find:*)" "Bash(date:*)" "Bash(stat:*)" "Bash(cp:*)" "Bash(touch:*)" "Bash(rmdir:*)" "Bash(jq:*)" \\
    "Bash(shasum:*)" "Bash(sha256sum:*)" "Bash(echo:*)" "Bash(head:*)" "Bash(wc:*)" "Bash(grep:*)" "Bash(sort:*)"
EOF
fi
chmod +x "$work/run-claude.sh"
: > "$work/claude-calls.log"
export MEETING_NOTES_CMD="$work/run-claude.sh" MEETING_NOTES_HEARTBEAT_MIN=0 MUESLI_DB="$work/no-muesli.db"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $*"; }
bad() { fail=$((fail+1)); echo "  FAIL  $*"; }
calls() { wc -l < "$work/claude-calls.log" | tr -d ' '; }
tick() { # now, [--reconcile]
  local now="$1"; shift
  MEETING_NOTES_NOW="$now" "$root/scripts/meeting-notes-trigger.sh" --dir "$ws" "$@" >/dev/null 2>&1
  echo "  (watcher exit $?, $(tail -1 "$ws/.trigger.log" 2>/dev/null || echo 'no log'))"
}
fingerprint() { (cd "$ws" && find . -type f ! -name '.schedule.json' ! -name '.trigger*' ! -name 'index.md' | sort | xargs -I{} shasum "{}"); }
check_mock() { python3 -I "$root/tests/checks/check_mock.py" "$ws" | tail -1; }

echo "Work dir: $work"
echo
echo "1. 18:05: the day's transcripts are in the inbox. The watcher should start a quick run."
b=$(calls); tick 2026-10-28T18:05:00Z
[ "$(calls)" -gt "$b" ] && ok "watcher started Claude" || bad "watcher didn't start Claude"
if [ "$dry" -eq 0 ]; then
  r=$(check_mock); echo "  checker: $r"
  [[ "$r" == "83/83"* ]] && ok "all notes, indexes, ledger and privacy checks" || bad "output checks ($r; run: python3 tests/checks/check_mock.py $ws)"
fi

echo
echo "2. 18:10: nothing new. The watcher shouldn't start Claude."
b=$(calls); tick 2026-10-28T18:10:00Z
[ "$(calls)" -eq "$b" ] && ok "no Claude run" || bad "Claude ran with nothing to do"

echo
echo "3. 18:30: the Coffee with Jo dictation arrives. A quick run should fill in only that placeholder."
before=$(fingerprint)
sleep 1
cat > "$ws/_inbox/wispr/wispr-2026-10-28T15-03.txt" <<'EOF'
Coffee with Jo, my dictated notes.
Jo is moving to the data platform team in January. We agreed I'll introduce Jo to Priya before then.
Jo will send me the migration doc by Monday.
EOF
b=$(calls); tick 2026-10-28T18:30:00Z
[ "$(calls)" -gt "$b" ] && ok "watcher started Claude for the new file" || bad "watcher ignored the new file"
if [ "$dry" -eq 0 ]; then
  jo="$ws/_unsorted/2026-10-28_coffee-with-jo/notes.md"
  grep -q '^status: complete' "$jo" 2>/dev/null && ok "placeholder upgraded to complete" || bad "placeholder not upgraded"
  grep -qi 'migration' "$jo" 2>/dev/null && ok "note uses the new transcript" || bad "note doesn't mention the migration doc"
  changed=$(diff <(echo "$before") <(fingerprint) | grep '^[<>]' | grep -v 'coffee-with-jo\|\.ledger\.jsonl\|_log/\|wispr-2026-10-28T15-03' || true)
  [ -z "$changed" ] && ok "no other note or transcript changed" || bad "unexpected changes: $changed"
fi

echo
echo "4. 18:35: daily reconcile with nothing new. Nothing should change."
before=$(fingerprint)
b=$(calls); tick 2026-10-28T18:35:00Z --reconcile
[ "$(calls)" -gt "$b" ] && ok "reconcile ran" || bad "reconcile didn't run"
if [ "$dry" -eq 0 ]; then
  [ "$before" = "$(fingerprint)" ] && ok "no files changed" || bad "files changed: $(diff <(echo "$before") <(fingerprint) | grep '^[<>]')"
  [ ! -e "$ws/.run.lock" ] && ok "lock released" || bad "lock left behind"
fi

echo
echo "$pass passed, $fail failed. Logs: $ws/.trigger.log, $work/claude-calls.log"
[ "$fail" -eq 0 ]
