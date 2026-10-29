#!/usr/bin/env bash
# Create a fresh mock workspace for an agent test run.
#
#   tests/make-workspace.sh inbox  <dir>   # transcripts as inbox files (Granola export, Zoom .vtt, Wispr)
#   tests/make-workspace.sh muesli <dir>   # transcripts from the fake muesli-cli, plus an audio file in the inbox
#
# All data is fictional. The mock day is 2026-10-28 (UTC); run the agent with "now" = 2026-10-28T18:05:00Z.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
scenario="${1:?scenario: inbox | muesli}"; dir="${2:?target directory}"
[ -e "$dir" ] && { echo "$dir already exists" >&2; exit 1; }
mkdir -p "$dir/_inbox/wispr"
cp "$here/fixtures/workspace/config.md" "$dir/"
cp "$here/fixtures/workspace/_inbox/calendar-2026-10-28.ics" "$dir/_inbox/"
cp "$here/fixtures/workspace/_inbox/wispr/wispr-2026-10-28T16-01.txt" "$dir/_inbox/wispr/"   # private (HR) canary
case "$scenario" in
  inbox)
    cp -R "$here/fixtures/workspace/_inbox/granola" "$here/fixtures/workspace/_inbox/zoom" "$dir/_inbox/"
    cp "$here/fixtures/workspace/_inbox/wispr/wispr-2026-10-28T13-02.txt" "$dir/_inbox/wispr/" ;;
  muesli)
    mkdir -p "$dir/_inbox/voice"
    printf 'FAKE-AUDIO-BYTES' > "$dir/_inbox/voice/2026-10-28 15-02.m4a"
    data="$(mktemp -d)"; cp "$here/fixtures/muesli/data/"*.json "$data/"; : > "$data/calls.log"
    echo "Fake Muesli: export PATH=\"$here/fixtures/muesli/bin:\$PATH\" MUESLI_FAKE_DATA=\"$data\""
    echo "Muesli call log: $data/calls.log" ;;
  *) echo "unknown scenario: $scenario" >&2; exit 2 ;;
esac
echo "Workspace ready: $dir"
