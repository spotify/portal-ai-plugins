---
name: actions
description: Discover, inspect, and invoke Spotify Portal actions through the Portal CLI or, in Claude Code, Portal MCP. Use when the user asks what Portal can do, names an action ID, wants to run a Portal operation, or needs a decision between deterministic CLI execution and dynamic MCP tool discovery.
---

# Use Portal Actions

Use the CLI whenever the action ID is known directly or can be found through one action listing. In Claude Code, use Portal MCP only when the required actions cannot be named up front and dynamic tool discovery is genuinely needed.

Portal MCP is not currently supported in Codex or Cursor. Always use the CLI in those hosts.

## Discover and inspect

```bash
npx @spotify/portal-cli actions list --json
npx @spotify/portal-cli actions <action-id> --help
```

Prefer a dedicated CLI workflow such as `search`, `owner`, or `service` when it already matches the user's goal.

## Invoke safely

For read-only actions, use JSON output and pass only documented flags.

For mutations:

1. Inspect generated help.
2. Preview the exact input with `--dry-run --json`.
3. Show the user what will change.
4. Execute only after user authorization.
5. Add `--yes` only when the action is marked destructive and the user authorized it.

```bash
npx @spotify/portal-cli actions <action-id> --input '<json>' --dry-run --json
```

Never infer successful execution from a dry run, and never claim MCP access succeeded until a real tool call completes.
