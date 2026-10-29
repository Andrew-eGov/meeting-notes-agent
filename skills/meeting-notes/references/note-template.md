# notes.md template

Every note uses exactly this structure. Front matter keys are required, even if empty.

## Full note

```markdown
---
title: Acme weekly sync
date: 2026-10-29
start: "14:00"
end: "14:45"
timezone: Europe/London
meeting_id: <calendar event id, or source:id in transcript-first mode>
series_id: <recurring series id, or empty>
calendar_link: <event link, or empty>
attendees:
  - Sam Lee <sam@acme.com>
  - Priya Shah <priya@example.com>
folder: Acme
also_in: [Hiring]          # other matching folders, or []
source: granola            # connector name, attachment:<provider>, inbox:<subfolder>, or none
status: complete           # complete | provisional (built from dictation/notes; upgraded when a transcript arrives) | placeholder
routing: rule              # rule | pending-rule | unsorted
agent_version: 0.2.0
---

# Acme weekly sync — 2026-10-29

## TL;DR
Two or three sentences: what the meeting was for and what came out of it.

## Decisions
- Ship the Falcon beta on Nov 12 instead of Nov 5.
- (If none: "No decisions recorded.")

## Action items
- [ ] @Sam Lee — Send revised proposal (due Fri Oct 31)
- [ ] @Priya Shah — Book design review
- [ ] @unassigned — Confirm budget with finance
- (If none: "No action items recorded.")

## Discussion
### Beta timeline
- Key points, grouped by topic.

### Pricing
- ...

## Open questions
- Unresolved items and follow-ups for next time.
- (If none: "None.")

---
[Transcript](transcript.md)
```

Action items always use the form `- [ ] @Owner — Task (due …)`, so they can be collected across notes. The user closes an item by ticking it (`- [x]`) in the note.

## Placeholder note (calendar-first mode, no transcript yet)

```markdown
---
(same front matter, with source: none, status: placeholder)
---

# Acme weekly sync — 2026-10-29

> No transcript found yet. This note will be filled in automatically if a transcript shows up within the catch-up window, from a connected notetaker or a file in `_inbox/`.

## Agenda (from the invite)
- The invite description, if any. Otherwise "No agenda in invite."

## Attendees
- Sam Lee, Priya Shah
```

## transcript.md

```markdown
---
title: Acme weekly sync
date: 2026-10-29
meeting_id: <id>
source: granola
---

<transcript text exactly as received>
```
