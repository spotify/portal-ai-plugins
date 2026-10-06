---
name: troubleshoot-shift
description: 'Diagnose why a Fleetshift shift or job failed: find failed targets, pull their job logs and status, and explain the root cause and the safe next step. Read-only and safe to run anytime. Use when a shift run fails, a target ends in jobFailed/stopped, or a soundcheck check is still failing after a run.'
---

# Troubleshoot a Fleetshift shift

This skill is **read-only**. It only inspects shift, target, job, and log
state to explain _why_ something failed — it never mutates, triggers, or
re-opens anything, and needs no confirmation. If a fix is needed, it hands off
to the mutating skills (`run-shift`, `create-prs`), which enforce their own
explicit confirmation.

Use this for:

- A target whose status is `jobFailed`, `stopped`, or `skipped`.
- A shift where the status breakdown shows failures.
- A soundcheck check that is still failing after a shift ran.

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

### 1. Identify the shift and failing targets

```bash
# Find the shift
npx @spotify/portal-cli actions fleetshift:list-shifts --input '{}' --json

# Its definition + aggregate status breakdown
npx @spotify/portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}' --json

# The failing targets specifically
npx @spotify/portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","status":"jobFailed"}' --json
```

### 2. Pull job status and logs for the failed targets

For each failed (or stopped/skipped) target:

```bash
# Job detail: terminal state, timestamps, references
npx @spotify/portal-cli actions fleetshift:get-job-status --input '{"jobIdentifier":"<job-identifier>"}' --json

# Raw logs + human-readable summary for the target — the main diagnostic
npx @spotify/portal-cli actions fleetshift:get-job-logs --input '{"shiftName":"<shift-name>","targetId":"component:default/my-service"}' --json
```

Look for the concrete reason: agent error, repo access/permissions, build
failure, timeout, or a missing resource. Quote the relevant log lines in your
report.

### 3. Explain the root cause

Summarize per failed target:

- status and any error/summary from the job.
- the specific log excerpt that shows the cause.
- what that implies (e.g. "repo cannot be cloned — likely a permissions
  problem in target X", "the agent exceeded the timeout", "the change was a
  no-op").

If the failure is a soundcheck scenario, cross-check with
`fleetshift:find-shift-for-soundcheck` to confirm the shift actually matches
the failing checks before suggesting a re-run.

### 4. Recommend the safe next step

Do **not** perform it yourself — recommend one of:

- **Re-run the failed targets** → `run-shift` skill (requires explicit user
  confirmation; consider re-running only the failed targets).
- **Open PRs** once a target is `jobComplete` → `create-prs` skill (requires
  explicit user confirmation).
- **Check on the overall state** later → `check-shift` skill (read-only).

## Boundaries

- This skill never calls `create-shift`, `trigger-shift`, `create-prs`,
  `close-prs`, or `delete-shift`, and never mutates any state.
- If the diagnosis is inconclusive, say so plainly and suggest the user
  review the linked `portalJobUrl` for the failed job.
