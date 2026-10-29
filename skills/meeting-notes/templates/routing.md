# Meeting Routing Rules

Each `##` section is one folder. The agent files each meeting into the best-matching folder.

Priority when several folders match: **series** > **domains** > **title** > **description**.

- `status: active` = approved by you.
- `status: pending` = created automatically. It works now, and you review it with `/meeting-notes review`.

_No rules yet. Run `/meeting-notes setup` to scan your recent meetings and propose folders._

<!-- Example:

## Acme
- status: active
- series: "Acme weekly sync"
- domains: acme.com
- title: Acme, Project Falcon
- description: Falcon launch, Acme renewal
- notes: Client work for Acme Corp

-->
