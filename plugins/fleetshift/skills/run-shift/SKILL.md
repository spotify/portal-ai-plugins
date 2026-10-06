---
name: run-shift
description: 'Run an existing Fleetshift shift against its targets: triggers the agent jobs and monitors them to completion with a bounded wait. Also covers the kill switch for stopping a run (halt triggering, stop running jobs) when the user changes their mind. Use when the user wants to actually execute a previously created shift (see create-shift), or to stop or cancel one. Requires explicit user confirmation before triggering, and never waits indefinitely — it polls with a hard time/attempt cap and reports where things stand.'
---

# Run a Fleetshift shift

Running a shift triggers an agent job per target repository, then monitors
each triggered job until it finishes (or until a bounded wait expires).

> **Mutating action — explicit confirmation required.** Do **not** call
> `fleetshift:trigger-shift` until the user has explicitly confirmed which
> shift and which targets to run. Ask for a clear "yes" first.

## Kill switch: stop a shift

If the user says stop, cancel, abort, "wait", "never mind", or otherwise
changes their mind at **any** point, do this right away. Stopping doesn't
need the confirmation step that triggering does:

1. **Stop triggering.** Don't call `fleetshift:trigger-shift` for any target
   that hasn't been triggered yet, and drop the rest of the batch.
2. **Stop polling.** End the monitor loop.
3. **Stop the running jobs.** No Portal CLI action can stop a job, so send
   the user to the Fleetshift UI, where stopping takes one click:
   - **All running jobs in a shift:** open
     `<portal-base-url>/fleetshift/shifts/<shift-name>`, select the running
     targets, and press **Stop (N)**.
   - **A single job:** open its `portalJobUrl` (from the `trigger-shift`
     response) and press **Stop**.

   List every triggered job that wasn't in a terminal state as a markdown
   link to its `portalJobUrl`, so the user has them all in one place.
4. **Confirm it worked.** Once the user says they've stopped the jobs, call
   `fleetshift:get-job-status` once for each job and check that it reports
   `stopped` (or another terminal state). Report anything still running.

Stopping doesn't delete the shift, and it doesn't touch PRs that were
already opened. Closing PRs (`fleetshift:close-prs`) or deleting the shift
(`fleetshift:delete-shift`) are separate, destructive steps. Do them only if
the user explicitly asks, and get a clear "yes" first.

## Prerequisites

- The Portal CLI (`portal-cli`) is installed and authenticated.
- A shift definition already exists (see the `create-shift` skill).

## 1. Locate the shift and its targets (read-only)

```bash
# Find the shift (list if unsure of the exact name)
portal-cli actions fleetshift:list-shifts --input '{}'

# Its definition and status breakdown
portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}'

# Its targets and their current status
portal-cli actions fleetshift:get-shift-targets --input '{"shiftName":"<shift-name>"}'
```

- Prefer running only targets that are `pending` (or re-running ones you
  agree to re-run). Surface any targets that are already `running`,
  `finished`, or `jobFailed` and confirm the intended scope.
- If the shift backs a failing soundcheck check, route through
  `fleetshift:find-shift-for-soundcheck` first and confirm the matched shift
  with the user before running.

## 2. Confirm explicitly, then trigger (mutating)

Present the shift name and the exact list of targets to run, and get explicit
confirmation. `trigger-shift` runs **one target per call** and returns a
`jobIdentifier` plus a `portalJobUrl`:

```bash
portal-cli actions fleetshift:trigger-shift --input '{"shiftName":"<shift-name>","targetId":"component:default/my-service","repo":"my-org/my-service"}'
```

- Record the `jobIdentifier` and `portalJobUrl` from **every** invocation —
  you need the identifier to monitor the job.
- Trigger each confirmed target and collect the identifiers. If a shift has
  many targets, batch the triggers, then move to monitoring.
- Before each trigger call, check whether the user has asked to stop. If
  they have, switch to the **Kill switch** above instead of triggering the
  rest.
- When you start triggering, tell the user once that they can say "stop" at
  any time to halt the run.
- Never trigger targets the user did not confirm, and never trigger a
  destructive workflow (none of these skills expose one).

## 3. Bounded monitor (never wait forever)

After triggering, monitor each job with `fleetshift:get-job-status`, passing
the `jobIdentifier` you recorded:

```bash
portal-cli actions fleetshift:get-job-status --input '{"jobIdentifier":"<job-identifier>"}'
```

Terminal states to stop on: `jobComplete`, `jobFailed`, `stopped`, `skipped`,
`noChanges` (and, after PRs exist, `prOpen`/`prMerged`/`prClosed`).

- Poll with a **bounded loop only**: at most **10 polls** with a **minimum
  interval of 30 seconds**, and never continue past a **total wall-clock cap
  of 15 minutes** per shift. Stop on the first terminal state.
- If a job reaches `jobFailed` (or `stopped`/`skipped`), stop polling that
  job, note it, and continue to the `troubleshoot-shift` skill for diagnosis —
  do not silently retry it.
- If the bound is hit with jobs still non-terminal, stop and report:
  they are still running, with the `portalJobUrl` for each so the user can
  keep watching. Do not keep polling past the cap.

## 4. Report

Summarize per target: status, and any `prUrl`. For every triggered job,
always include its `portalJobUrl` as a markdown link. If any targets reached
`jobComplete`, suggest the `create-prs` skill (which itself requires explicit
confirmation).

## After

- To check on the shift later (even days/weeks after): `check-shift`.
- To open PRs for completed targets: `create-prs`.
- To diagnose failed jobs: `troubleshoot-shift`.
- To stop a run in progress: see **Kill switch** above.
