---
name: service
description: Inspect a Spotify Portal service's owner, team, on-call contact, Slack channel, runbook, build, deployment, runtime, incidents, or documentation. Use when the user asks who owns a service, whether a service is healthy, where its runbook or docs are, or requests a service briefing.
---

# Inspect a Portal Service

Use the Portal CLI as the source of truth. Prefer JSON output when composing an answer.

## Resolve the service

Run help before relying on command flags:

```bash
npx @spotify/portal-cli owner --help
```

For a service name:

```bash
npx @spotify/portal-cli owner <service-name> --json
```

The result includes the canonical entity reference. If the user provided an entity reference, parse its kind, namespace, and name and pass the corresponding owner flags.

## Choose the narrowest workflow

| User need | Command |
| --- | --- |
| Owner, on-call, Slack, or runbook | `npx @spotify/portal-cli owner <service-name> --json` |
| Build, deployment, runtime, or incidents | `npx @spotify/portal-cli service status <entity-ref> --json` |
| Service documentation | `npx @spotify/portal-cli service docs <entity-ref> --json` |
| Complete service briefing | Run all available workflows above |

Run `npx @spotify/portal-cli service --help` first because service workflows depend on the actions registered by the selected Portal instance.

Treat unavailable workflows and dimensions as unavailable, not healthy. Preserve freshness evidence and source links. Keep the response concise and include the canonical entity reference.
