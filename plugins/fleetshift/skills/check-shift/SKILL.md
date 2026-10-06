---
name: check-shift
description: 'Read-only status check on Fleetshift shifts: what ran, which targets finished/failed, which PRs were opened and their state. Safe to run days or weeks after a shift was created or run. Use when the user asks "how is my shift going", "what happened to that fleetshift", "are the PRs merged yet", or wants a recap of a shift they ran a while ago.'
---

# Check a Fleetshift shift

This skill is **read-only and idempotent**. It never mutates anything and
needs no confirmation, so it is safe to run anytime — including days or weeks
after a shift was created or run. Check `portal-cli actions fleetshift:<action>`
calls below never change state.

Use it to answer:

- What shifts exist and how they are progressing overall.
- Which targets of a shift finished, failed, are still queued, or are running.
- Whether PRs were opened for a shift and their current state (open/merged/
  closed).

## Workflow (all read-only)

### 1. List what exists

```bash
portal-cli actions fleetshift:list-shifts --input '{}'
```

Returns every shift with summary info (name, owner, target count, progress).
Use this to find the shift the user is asking about when they don't recall the
exact name.

### 2. Drill into one shift

```bash
portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}'
```

Returns the shift definition **and** an aggregate `statusBreakdown` (counts of
pending / running / finished / failed targets). This is the fastest
"how is it going" answer.

### 3. Inspect individual targets

```bash
# All targets of the shift
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>"}'

# Only targets in a given state, e.g. failed or finished
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","status":"jobFailed"}'

# Paginate a large shift if needed
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","limit":100,"offset":0}'
```

Returns per-target status and `prUrl`/`prNumber` when a PR exists.

### 4. (Optional) Check a specific job or its logs

If the user wants detail on one run — and you have its `jobIdentifier` from a
previous `run-shift` session:

```bash
portal-cli actions fleetshift:get-job-status --input '{"jobIdentifier":"<job-identifier>"}'

portal-cli actions fleetshift:get-job-logs --input '{"shiftName":"<shift-name>","targetId":"component:default/my-service"}'
```

Both are read-only and idempotent — fine to call months later.

## Presenting results

- Show overall progress (e.g. "12/20 finished, 3 failed, 5 pending").
- Link each opened PR (`prUrl`) and, when available, its merge state.
- If targets failed, summarize the failed ones and point to the
  `troubleshoot-shift` skill for diagnosis.

## Boundaries

- This skill makes **no** `create-shift`, `trigger-shift`, or `create-prs`
  calls, and never archives, deletes, or closes anything.
- If the user wants to (re)run a shift or open PRs, hand off to `run-shift`
  or `create-prs` — each of those requires explicit user confirmation.
