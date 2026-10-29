# Running it automatically

The scheduled run processes today plus any of the last `catch_up_days` that are still missing notes. A missed day (laptop closed, app not running) is filled in on the next run.

It needs access to your local `Meetings/` folder, so it has to run on your own machine. Cloud-hosted schedulers can't see that folder.

The examples run at 6:00 pm on weekdays. Change the time to suit you.

## Claude desktop app (easiest)

Ask Claude in a Code session opened in the folder that contains `Meetings/`:

> Create a scheduled task that runs `/meeting-notes` at 6pm on weekdays.

It runs while the app is open.

## macOS / Linux: cron with the Claude Code CLI

```bash
crontab -e
```

Add this line, changing the path to the folder that contains `Meetings/`:

```cron
3 18 * * 1-5 cd "$HOME/Documents" && claude -p "/meeting-notes:meeting-notes" --permission-mode acceptEdits >> "$HOME/.meeting-notes.log" 2>&1
```

Use `/meeting-notes` instead of `/meeting-notes:meeting-notes` if you installed it as a plain skill rather than a plugin.

The connectors you use must be available to the CLI. claude.ai connectors are, once you're signed in with `claude`; `claude mcp add --scope user …` connectors are too.

On macOS you may need to give your terminal **Full Disk Access** if `Meetings/` is in a protected folder (Desktop, Documents).

## Windows: Task Scheduler

```powershell
schtasks /Create /TN "Meeting notes" /SC WEEKLY /D MON,TUE,WED,THU,FRI /ST 18:03 /TR "cmd /c cd /d %USERPROFILE%\Documents && claude -p \"/meeting-notes:meeting-notes\" --permission-mode acceptEdits"
```

## Checking it worked

- `Meetings/index.md` shows an "Updated" time.
- Run `/meeting-notes status` for the last run time, the sources found, and pending items.
- For cron or Task Scheduler, check the log file.
