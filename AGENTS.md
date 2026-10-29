# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, Gemini CLI, …) working in or with this repository.

## Using the agent

The agent is a single skill: [`skills/meeting-notes/SKILL.md`](skills/meeting-notes/SKILL.md). When the user asks to process, file or catch up on meeting notes, read that file and follow it. Its `references/` and `templates/` folders are loaded from there as needed.

It needs:
- a writable folder for the workspace (default `./Meetings`, or `$MEETING_NOTES_DIR`),
- optionally, tools that can list calendar events and fetch meeting transcripts (any MCP connector; see `skills/meeting-notes/references/providers.md`),
- optionally, a shell for desktop notifications.

## Changing the agent

- Keep `SKILL.md` focused on the workflow; put detail in `references/`.
- New providers go in `references/providers.md` as capabilities plus search keywords, never as hard-coded tool names.
- New settings go in `templates/config.md` with a default. The skill must keep working when a setting is missing, so older workspaces don't break.
- Bump `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and add a line to `CHANGELOG.md`.
- Run `./scripts/validate.sh` before committing.
