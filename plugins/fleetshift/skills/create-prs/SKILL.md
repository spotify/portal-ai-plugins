---
name: create-prs
description: 'Open pull requests from completed Fleetshift shift runs. Use after a shift has run and targets reached a "finished/jobComplete" state — this turns the agent-made changes into reviewable PRs on the target repositories. Requires explicit user confirmation before creating any PRs. Only opens PRs; it never closes, archives, or reverts anything.'
---

# Create PRs from a Fleetshift shift

Once Fleetshift has finished running a shift on a set of targets (the agent
job completed successfully), you can open one pull request per completed
target. Only targets whose job is complete are eligible for a PR.

> **Mutating action — explicit confirmation required.** Do **not** call
> `fleetshift:create-prs` until the user has explicitly confirmed how many PRs
> will be opened and for which targets. Ask for a clear "yes" first.

## Prerequisites

- The Portal CLI (`portal-cli`) is installed and authenticated.
- The shift has been run and at least one target reached a completed state
  (see the `run-shift` skill).

## 1. Confirm PRs can be opened (read-only)

Check the shift's status breakdown and the individual targets before creating
anything:

```bash
# Aggregate: how many targets are jobComplete vs still running/failed
portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}'

# Only the completed targets (the ones PRs would be opened for)
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","status":"jobComplete"}'

# If you have a job identifier from a prior run, you can confirm its status too
portal-cli actions fleetshift:get-job-status --input '{"jobIdentifier":"<job-identifier>"}'
```

- Skip targets still `running` or `failed` — they are not PR-eligible.
- If a target already has a `prUrl`, it is already covered; don't open a
  duplicate.

## 2. Confirm explicitly, then create (mutating)

Present the exact number of PRs and the affected repositories to the user and
get explicit confirmation before opening anything:

```bash
portal-cli actions fleetshift:create-prs --input '{"shiftName":"<shift-name>"}'
```

- Confirm the count with the user first (e.g. "This opens 12 PRs — proceed?").
- `create-prs` only **opens** PRs. It never closes, merges, or reverts PRs or
  branch changes.

## 3. Verify and report

Confirm each successfully created PR and report it:

```bash
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>","status":"jobComplete"}'
```

Link each opened PR (`prUrl`/`prNumber`). State clearly that the PRs are
created but not merged, and that the user must review/merge them.

## Boundaries

- **No destructive actions.** This skill never calls `close-prs`,
  `delete-shift`, or any action that removes or reverts work.
- If a target is `jobFailed` and the user wants it fixed, point to the
  `troubleshoot-shift` skill (diagnosis) and `run-shift` (re-run) — both
  keep their own explicit confirmation requirement.
