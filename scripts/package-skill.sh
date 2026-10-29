#!/usr/bin/env bash
# Build dist/meeting-notes-skill.zip for uploading to Claude (Settings → Capabilities → Skills).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/dist/meeting-notes-skill.zip"

mkdir -p "$root/dist"
rm -f "$out"
(cd "$root/skills" && zip -qr "$out" meeting-notes -x '*.DS_Store')
echo "Built $out"
