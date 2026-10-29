"""Verify the Muesli-source run. Usage: python3 -I check_muesli.py <Meetings dir> <muesli calls.log>"""
import json
import re
import sys
from pathlib import Path

ws, calls_log = Path(sys.argv[1]), Path(sys.argv[2])
results = []


def check(name, ok, detail=""):
    results.append((ok, name, detail))


def fm(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    return dict(re.findall(r"^([a-z_]+):\s*(.*)$", m.group(1), re.M)) if m else {}


notes = {}
for p in ws.rglob("notes.md"):
    meta = fm(p.read_text())
    notes[meta.get("meeting_id", "").split("_2026")[0]] = (p, meta, p.read_text())

def get(mid):
    return notes.get(mid, (None, {}, ""))

expect = {
    "evt-acme-weekly@mock": ("complete", "muesli", "Acme"),
    "evt-acme-pricing@mock": ("complete", "muesli", "Acme"),
    "evt-falcon-review@mock": ("complete", "muesli:dictation", "Project Falcon"),
    "evt-coffee-jo@mock": ("complete", "inbox:voice", "_unsorted"),
}
check("exactly 4 notes", len(notes) == 4, str(sorted(notes)))
for mid, (status, source, folder) in expect.items():
    p, meta, text = get(mid)
    check(f"{mid}: status {status}", meta.get("status") == status, meta.get("status"))
    check(f"{mid}: source {source}", meta.get("source") == source, meta.get("source"))
    check(f"{mid}: folder {folder}", p is not None and p.parent.parent.name == folder, str(p))
    check(f"{mid}: transcript.md saved", p is not None and (p.parent / "transcript.md").exists())

_, _, acme = get("evt-acme-weekly@mock")
check("Acme sync: Nov 12 decision from Muesli transcript", re.search(r"nov(ember)?\.? 12", acme, re.I) is not None)
_, _, pricing = get("evt-acme-pricing@mock")
check("Pricing (time-matched Muesli meeting): two-year term captured", re.search(r"two-year|2-year", pricing, re.I) is not None)
_, _, falcon = get("evt-falcon-review@mock")
check("Falcon: both dictations used (checklist + admin question)", "checklist" in falcon.lower() and "admin" in falcon.lower())
check("Falcon: grocery dictation not mixed in", "grocer" not in falcon.lower() and "milk" not in falcon.lower())
check("Falcon: TL;DR says dictated", re.search(r"dictat", falcon.split("## Decisions")[0], re.I) is not None)
p, _, jo = get("evt-coffee-jo@mock")
check("Coffee: audio transcription used (migration doc)", "migration" in jo.lower())
check("Coffee: audio file moved into meeting folder", p is not None and any(f.suffix == ".m4a" for f in p.parent.iterdir()))
check("Coffee: audio no longer in inbox", not (ws / "_inbox/voice/2026-10-28 15-02.m4a").exists())

hits = [str(f.relative_to(ws)) for f in ws.rglob("*") if f.is_file() and "_inbox" not in f.parts and "CANARY" in f.read_text(errors="ignore")]
check("HR Muesli recording text appears nowhere", not hits, str(hits))
check("HR not listed anywhere", not [f for f in ws.rglob("*.md") if "_inbox" not in f.parts and f.name != "config.md" and "HR check-in" in f.read_text()])

calls = calls_log.read_text().splitlines()
check("never called update-notes", not any("update-notes" in c for c in calls), str(calls))
check("never used --save-meeting", not any("--save-meeting" in c for c in calls))
check("never fetched HR recording (meetings get 104)", "meetings get 104" not in calls, str([c for c in calls if "get" in c]))
check("used meetings list", any(c.startswith("meetings list") for c in calls))
check("audio transcribed via muesli-cli", any(c.startswith("transcribe") for c in calls))

for name in ["routing.md", "_pending.md", "index.md", ".ledger.jsonl", "_log/2026-10.md"]:
    check(f"layout file created: {name}", (ws / name).exists())
rows = [json.loads(l) for l in (ws / ".ledger.jsonl").read_text().splitlines() if l.strip()] if (ws / ".ledger.jsonl").exists() else []
check("ledger: 4 valid JSON lines", len(rows) == 4)
check("ledger sources match", sorted(r.get("source") for r in rows) == sorted(v[1] for v in expect.values()), str([r.get("source") for r in rows]))

passed = sum(ok for ok, _, _ in results)
for ok, name, detail in results:
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok or not detail else f"   [{detail}]"))
print(f"\n{passed}/{len(results)} checks passed")
