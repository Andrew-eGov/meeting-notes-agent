# Contributing

Issues and pull requests are welcome.

- **New calendar or notetaker:** add it to `skills/meeting-notes/references/providers.md` as a capability with search keywords. Don't hard-code tool names.
- **New setting:** add it with a default to `skills/meeting-notes/templates/config.md`, and make sure the skill still works when it's missing.
- **Release:** bump the version in both `.claude-plugin/*.json` files, update `CHANGELOG.md`, then tag `vX.Y.Z`. The release workflow builds the skill zip.
- Run `./scripts/validate.sh` and `./tests/trigger-test.sh` before opening a PR. For changes to the skill, also do an agent run against a mock workspace (see `tests/README.md`).
- Never commit real meeting notes or transcripts.
