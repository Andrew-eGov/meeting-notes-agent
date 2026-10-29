# Meeting Notes Agent

An agent skill that turns your meetings into structured Markdown notes, filed in the right project folder automatically.

- **Finds your meetings** from any connected calendar (Google Calendar, Outlook/Microsoft 365), or straight from your transcripts if there's no calendar.
- **Gets the transcripts** from any connected notetaker (Granola, Fireflies, Otter, Fathom, Zoom, …), from local open-source notetakers like [Muesli](https://github.com/Muesli-HQ/muesli) (meetings, dictations and audio files via `muesli-cli`), from documents attached to the calendar invite (Google Meet transcripts, Notes by Gemini), or from files you drop in an inbox folder (Wispr Flow, voice memos, `.vtt`/`.srt` downloads).
- **Writes one note per meeting:** TL;DR, decisions, action items with owners, discussion, and open questions.
- **Files it by project** using rules you approve once. New clients or projects get their own folder automatically, for you to review.
- **Keeps overviews current:** a global `index.md` with all open action items, plus a "where things stand" summary for each project.
- **Skips sensitive meetings** (HR, legal, personal, …) completely.
- **Runs by itself:** right after each meeting ends, as soon as a transcript arrives, and as a daily 6 pm reconcile that catches anything missed. It also runs on demand.
- **Local or Google Drive:** keep the workspace on your computer, in a synced cloud folder, or directly on Google Drive through the Drive connector, with no computer needed.

No connectors are required to start. With only the inbox folder, it already works.

## Install

Pick whichever matches how you use Claude.

### Claude Code (CLI, desktop app, IDE): as a plugin

```bash
claude plugin marketplace add Andrew-eGov/meeting-notes-agent
```

```bash
claude plugin install meeting-notes@meeting-notes-agent
```

Or, inside a session: `/plugin marketplace add Andrew-eGov/meeting-notes-agent`, then `/plugin install meeting-notes@meeting-notes-agent`.

Updates come through `claude plugin update meeting-notes`.

### Claude Code: as a plain skill (no plugin system)

```bash
git clone https://github.com/Andrew-eGov/meeting-notes-agent.git
```

```bash
cp -R meeting-notes-agent/skills/meeting-notes ~/.claude/skills/
```

Use `~/.claude/skills/` for all your projects, or `<project>/.claude/skills/` for a single project.

### Claude.ai, the Claude desktop app, or Cowork: upload the skill

1. Download `meeting-notes-skill.zip` from the [latest release](https://github.com/Andrew-eGov/meeting-notes-agent/releases/latest), or build it with `./scripts/package-skill.sh`.
2. In Claude, go to **Settings → Capabilities → Skills** and upload the zip.

In a plain web chat there's no persistent folder, so notes come back as files to download. Automatic filing needs a local folder (Claude Code, desktop or Cowork).

### Other agents that read `SKILL.md` / `AGENTS.md`

The skill is plain Markdown in the open Agent Skills format. Point your agent at `skills/meeting-notes/SKILL.md`; [AGENTS.md](AGENTS.md) explains how.

## Quick start

```text
/meeting-notes init      # create the Meetings/ workspace
/meeting-notes status    # see which calendar and transcript sources were found
/meeting-notes setup     # propose project folders from your recent meetings (you approve)
/meeting-notes           # process today + catch up on the last 7 days
```

When installed as a plugin, the command is `/meeting-notes:meeting-notes`. You can also just ask: "process my meetings from yesterday".

Other commands: `/meeting-notes quick` (just-ended meetings and new transcripts), `/meeting-notes reconcile`, `/meeting-notes 2026-10-27`, `/meeting-notes 2026-10-20..2026-10-24`, `/meeting-notes review`.

## Where notes go

By default, `Meetings/` in the folder you run it from. To use one fixed location everywhere, set an environment variable:

```bash
echo 'export MEETING_NOTES_DIR="$HOME/Documents/Meetings"' >> ~/.zshrc
```

Or pass `--dir <path>` on any run.

**On Google Drive:**
- **With Google Drive for desktop installed:** point `--dir` (or `MEETING_NOTES_DIR`) at the synced folder, e.g. `~/Library/CloudStorage/GoogleDrive-you@example.com/My Drive/Meetings`. Everything works, including instant triggers.
- **Without a synced folder** (claude.ai, cloud routines, any machine): connect the Google Drive connector and use `--dir "drive:My Drive/Meetings"` or `--dir drive:<folder id>`. The agent reads and writes through the connector. Files are never edited in place: a new version is written and the old one goes to the Drive bin. See [storage](skills/meeting-notes/references/storage.md).

```
Meetings/
├── config.md            your settings
├── routing.md           folder rules
├── _pending.md          things waiting for your review
├── index.md             open action items + last 30 days
├── _log/2026-10.md      full monthly history
├── _inbox/              drop transcript files here (subfolders fine: wispr/, zoom/)
├── _unsorted/
└── Acme/
    ├── _project.md      where things stand + open actions
    └── 2026-10-29_acme-weekly-sync/
        ├── notes.md
        └── transcript.md
```

## Connecting sources (optional)

| Want | Do |
|---|---|
| Google Calendar | Claude **Settings → Connectors → Browse** → Google Calendar |
| Outlook / Microsoft 365 | Claude **Settings → Connectors → Browse** → Microsoft 365 |
| Granola | **Settings → Connectors → Add custom connector**, URL `https://mcp.granola.ai/mcp`, or in Claude Code: `claude mcp add granola --scope user --transport http https://mcp.granola.ai/mcp` |
| Any other notetaker | Add its connector; the agent finds it by what it can do (see [providers](skills/meeting-notes/references/providers.md)) |
| Muesli (open source, local) | Install [Muesli](https://github.com/Muesli-HQ/muesli). The agent finds its bundled `muesli-cli` automatically and only reads from it. Recordings are matched to calendar events by id |
| A tool with no connector | Export its transcripts into `Meetings/_inbox/`. Audio files work too when Muesli is installed |

Run `/meeting-notes status` afterwards to check what it found.

## Run it automatically

```bash
./scripts/install-scheduler.sh --dir ~/Documents/Meetings --reconcile-at 18:00
```

This installs a lightweight watcher that runs the agent after each meeting ends and whenever a transcript lands in `_inbox/`, plus a daily reconcile. It starts Claude only when there's work. See [docs/scheduling.md](docs/scheduling.md) for Linux, Windows, the Claude desktop app, and Drive-only setups.

## Settings

Everything lives in `Meetings/config.md`: calendar choice, source order, catch-up days, sensitive keywords, automatic folder creation, notifications. [See the template](skills/meeting-notes/templates/config.md).

## Privacy

- Everything stays in your local `Meetings/` folder. The agent only reads from your calendar and notetakers, and never writes to them.
- Meetings matching your sensitive keywords are skipped completely.
- Don't commit your `Meetings/` folder to a public repo. This repo contains only the agent.

## Docs

- [Design](docs/design.md): what the agent does and why
- [Scheduling](docs/scheduling.md)
- [Contributing](CONTRIBUTING.md)

## License

[MIT](LICENSE)
