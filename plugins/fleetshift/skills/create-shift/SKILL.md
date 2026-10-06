---
name: create-shift
description: 'Create a Fleetshift shift definition that runs an agent to apply transformations across a set of repository targets. Use when the user wants to set up a reusable, repeatable change (e.g. "add a header to every service", "migrate every repo from X to Y") that can later be run, checked on, and have PRs opened from it. Requires explicit user confirmation before creating the shift.'
---

# Create a Fleetshift shift

A Fleetshift **shift** is a reusable definition: an agent prompt plus a set of
repository targets and PR metadata. Once created, a shift can be run
(`run-shift`), checked on (`check-shift`), and have PRs opened from it
(`create-prs`).

This skill creates **agent**-type shifts only: the shift runs an LLM agent
against each target repository with a prompt you provide.

> **Mutating action — explicit confirmation required.** Do **not** call
> `fleetshift:create-shift` until the user has explicitly confirmed the shift
> name, the agent prompt, the target scope, and the PR metadata. A "looks
> good"/"go ahead" is not enough — ask and get a clear "yes" first.

## Prerequisites

- The Portal CLI (`portal-cli`) is installed and authenticated.
- You know what change the user wants and which repositories it applies to.

## 1. Scope the shift (read-only)

Before creating anything, understand the current state. These calls never
mutate anything and need no confirmation:

```bash
# Existing shifts (names, owners, progress) so you can avoid collisions
portal-cli actions fleetshift:list-shifts --input '{}'

# Details of an existing shift, if you want its targets/PR config as a model
portal-cli actions fleetshift:get-shift --input '{"shiftName":"<shift-name>"}'
```

- If a shift with the user's desired name already exists, surface it and
  propose a distinct name rather than overwriting.
- If the user wants a one-off change and there is no reusable target set,
  `create-shift` still works: the targets define the scope up front.

## 2. Draft the inputs from the user's goal

Keep user input to a **minimum**. Work out the goal (what should change and
why) from the conversation, then draft every field yourself. Don't send the
user a form to fill in. Only ask about something you can't reasonably infer,
usually just which repositories to target. Everything else gets a draft the
user can accept or tweak in the confirmation step.

- **name**: derive a short kebab-case id from the goal (e.g.
  `add-maintainers-header`), checked against `list-shifts` so it doesn't
  collide with an existing shift.
- **title**: derive a human-readable title from the goal.
- **shiftPrompt**: write a precise, self-contained instruction for the
  agent to follow in every target repo. Spell out the exact change, how to
  tell it's done, and what not to touch. Turn the user's goal into these
  concrete steps; don't just repeat it back. Look at a representative target
  repo first if that makes the prompt more accurate.
- **pullRequest**: default to `metadataMode: "generate"` with a title
  derived from the goal. Use `metadataMode: "manual"` only if the user has
  specific PR wording in mind.
- **targets**: build one or more structured `{ source, type, id }`
  references from whatever the user named (services, a team, a soundcheck
  check). Look up entity refs yourself instead of asking for them.
- **owner**: default to the caller. Set a group only if the user mentions
  a team.

## 3. Confirm explicitly, then create (mutating)

Show the user the drafted payload (shift name, prompt, target scope, PR
title/description) in one go, so they can confirm or adjust it in a single
reply, and get explicit confirmation:

```bash
portal-cli actions fleetshift:create-shift --input '{"name":"add-maintainers-header","title":"Add maintainers headers","type":"agent","shiftPrompt":"Add a Maintainers section to the README listing the owning team from catalog-info.yaml, keeping existing content intact.","targets":[{"source":"catalog","type":"entity","id":"component:default/my-service"}],"pullRequest":{"metadataMode":"generate","title":"Add maintainers header to README"}}'
```

- The shift type must be `"agent"`.
- Do not pass a custom image unless the user explicitly requests an allowed
  deployment-managed image.
- For more than 10 targets, summarize the full scope and confirm it separately,
  then pass `"confirmedLargeTargetSet":true`.

## 4. Verify

After a successful create, verify with a read-only call and report the result:

```bash
portal-cli actions fleetshift:get-shift --input '{"shiftName":"add-maintainers-header"}'
```

Report the shift name, owner, target count, and what to do next — usually
"run it" (see `run-shift`).

## After

- To run it: use the `run-shift` skill.
- To check on runs/PRs later: use the `check-shift` skill (read-only, safe
  to run days or weeks later).
- To open PRs for completed targets: use the `create-prs` skill.
