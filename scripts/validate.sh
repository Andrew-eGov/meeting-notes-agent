#!/usr/bin/env bash
# Check plugin manifests and skill files before committing or releasing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/skills/meeting-notes"
fail=0
err() { echo "✗ $*"; fail=1; }

for f in "$root/.claude-plugin/plugin.json" "$root/.claude-plugin/marketplace.json"; do
  jq empty "$f" 2>/dev/null || err "invalid JSON: ${f#$root/}"
done

plugin_v=$(jq -r .version "$root/.claude-plugin/plugin.json")
market_v=$(jq -r '.plugins[0].version' "$root/.claude-plugin/marketplace.json")
[ "$plugin_v" = "$market_v" ] || err "version mismatch: plugin.json $plugin_v vs marketplace.json $market_v"
grep -q "## $plugin_v" "$root/CHANGELOG.md" || err "CHANGELOG.md has no entry for $plugin_v"

head -1 "$skill/SKILL.md" | grep -q '^---$' || err "SKILL.md must start with front matter"
grep -q '^name: meeting-notes$' "$skill/SKILL.md" || err "SKILL.md front matter needs name: meeting-notes"
grep -q '^description: .\{20,\}' "$skill/SKILL.md" || err "SKILL.md front matter needs a description"

# Every <skill>/... file the skill mentions must exist
for ref in $(grep -o '<skill>/[A-Za-z0-9_./-]*' "$skill/SKILL.md" | sed 's#<skill>/##; s#[.*]*$##' | sort -u); do
  case "$ref" in *'*'*|*/) continue ;; esac
  [ -e "$skill/$ref" ] || err "SKILL.md references missing file: $ref"
done

for t in config.md routing.md _pending.md index.md; do
  [ -f "$skill/templates/$t" ] || err "missing template: $t"
done

[ $fail -eq 0 ] && echo "✓ all checks passed"
exit $fail
