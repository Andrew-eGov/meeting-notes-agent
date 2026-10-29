# Meeting Notes — Settings

Edit this file to change how the agent behaves; it's read on every run. Any setting you delete falls back to its default.

## Sources

- calendar: auto              # auto | google | outlook | none
- sources: connectors, local, attachments, inbox  # order to look for transcripts; connectors = Granola etc., local = Muesli etc. You can also name providers, e.g. muesli, granola, inbox
- match_window_minutes: 15    # a transcript matches if it starts between (meeting start - this) and (meeting end + this)

## Schedule window

- after_meeting_checks: 10, 45, 180  # minutes after a meeting ends to look for its transcript (quick runs)
- catch_up_days: 7            # each run also fills in meetings from the last N days that are still missing
- setup_lookback_days: 30     # how far back `setup` looks when proposing folders
- max_meetings_per_run: 25    # the rest are picked up on the next run

## Filing

- auto_create_folders: true   # false = unmatched meetings go to _unsorted with a suggestion instead
- ignore_domains:             # extra domains that never count as a "company" (e.g. your agency's domain)

## Sensitive meetings (skipped entirely: no notes, no transcript, no index entry)

Matched case-insensitively against the meeting title and description.

- sensitive_keywords: HR, legal, personal, interview, medical, performance review, private

## Notifications

- notify: desktop             # desktop | off

## You (filled in automatically from your calendar when possible)

- owner_name:
- owner_email:
- timezone:
