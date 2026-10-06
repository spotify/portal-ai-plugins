---
name: check-shift
description: 'Read-only status check on Fleetshift shifts: what ran, which targets finished/failed, which PRs were opened and their state. Safe to run days or weeks after a shift was created or run. Use when the user asks "how is my shift going", "what happened to that fleetshift", "are the PRs merged yet", or wants a recap of a shift they ran a while ago.'
---

# Check a Fleetshift shift

This skill is **read-only and idempotent**. It never mutates anything and
needs no confirmation, so it is safe to run anytime — including days or weeks
after a shift was created or run. The `npx @spotify/portal-cli actions
fleetshift:<action>` calls below never change state.

Use it to answer:

- What shifts exist and how they are progressing overall.
- Which targets of a shift finished, failed, are still queued, or are running.
- Whether PRs were opened for a shift and their current state (open/merged/
  closed).

## Prerequisites

- The Portal CLI is authenticated: `npx @spotify/portal-cli auth show`.
  If it isn't, ask the user to run `npx @spotify/portal-cli auth login`.
  If `auth list` shows more than one Portal instance, confirm which one
  with the user and pass `--instance <name>` on every call.
- If a Portal MCP server is connected instead, the same actions are
  available as `fleetshift_<action>` tools (for example
  `fleetshift_list-shifts`). They take the same input, but have no
  `--dry-run`, so the confirmation steps below matter even more.
- Never pass `--yes`. It's only needed for actions marked destructive
  (`close-prs`, `delete-shift`), and these skills don't call them.

## Workflow (all read-only)

### 1. List what exists

```bash
npx @spotify/portal-cli actions fleetshift:list-shifts --input '{}' --json
```

Returns every shift with summary info (name, owner, target count, creation
time). Use this to find the shift the user is asking about when they don't
recall the exact name. If they don't name one, pick the most relevant recent
shift they own instead of asking.

Don't report progress from `list-shifts`: its `completedCount` isn't
reliable. Get progress from `get-shift` in the next step.

### 2. Drill into one shift

```bash
npx @spotify/portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}' --json
```

Returns the shift definition **and** an aggregate `statusBreakdown`: target
counts per status (`pending`, `jobRunning`, `jobComplete`, `jobFailed`,
`stopped`, `noChanges`, `prCreating`, `prOpen`, `prMerged`, `prClosed`,
`skipped`). This is the fastest
"how is it going" answer.

### 3. Inspect individual targets

```bash
# All targets of the shift
npx @spotify/portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>"}' --json

# Only targets in a given state, e.g. jobFailed or jobComplete
npx @spotify/portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","status":"jobFailed"}' --json

# Paginate a large shift if needed
npx @spotify/portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","limit":100,"offset":0}' --json
```

Returns per-target status and `prUrl`/`prNumber` when a PR exists.

`get-shift-targets` may only list targets that have been triggered at least
once, so its `total` can be lower than the shift's target count. Count
untriggered targets from `statusBreakdown.pending` in `get-shift` instead.

### 4. (Optional) Check a specific job or its logs

If the user wants detail on one run — and you have its `jobIdentifier` from a
previous `run-shift` session:

```bash
npx @spotify/portal-cli actions fleetshift:get-job-status --input '{"jobIdentifier":"<job-identifier>"}' --json

npx @spotify/portal-cli actions fleetshift:get-job-logs --input '{"shiftName":"<shift-name>","targetId":"component:default/my-service"}' --json
```

Both are read-only and idempotent — fine to call months later.

## Presenting results

- Show overall progress from `statusBreakdown` (e.g. "12/20 complete,
  3 failed, 5 pending").
- Link each opened PR (`prUrl`) and, when available, its merge state.
- If targets failed, summarize the failed ones and point to the
  `troubleshoot-shift` skill for diagnosis.

## Boundaries

- This skill makes **no** `create-shift`, `trigger-shift`, or `create-prs`
  calls, and never archives, deletes, or closes anything.
- If the user wants to (re)run a shift or open PRs, hand off to `run-shift`
  or `create-prs` — each of those requires explicit user confirmation.
