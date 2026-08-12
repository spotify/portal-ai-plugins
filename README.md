<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/portal-icon-light.svg">
    <img src="assets/portal-icon-dark.svg" alt="Spotify Portal for Backstage" width="72">
  </picture>
</p>

<p align="center">
  Set up, diagnose, search, and operate Spotify Portal from Claude Code, Codex, and Cursor.
</p>

## Highlights

- Set up the Portal CLI for the current coding-agent host.
- Diagnose plugin, CLI, authentication, and action readiness without changing state.
- Search the software catalog and technical documentation using natural language.
- Build concise service briefings covering ownership, health, incidents, and documentation.
- Discover and safely invoke Portal actions with help, dry-run, and confirmation safeguards.

## Overview

[Spotify Portal for Backstage](https://backstage.spotify.com/docs/portal) is Spotify's managed internal developer portal. This plugin gives coding agents focused workflows for the Portal CLI.

The workflow skills are bundled as plugin behavior. They are not published or installed as standalone skill packages.

The marketplace also ships **shunt** (Claude Code only for now): a plugin that routes I/O-heavy agent work — bulk file reads and boilerplate generation — to AiKA modes running cheaper worker models, via the Portal CLI actions registry. See [`plugins/shunt/README.md`](plugins/shunt/README.md).

## Installation

### Claude Code

```bash
claude plugin marketplace add spotify/portal-ai-plugins
claude plugin install portal@portal
claude plugin install shunt@portal   # optional: token-saving AiKA delegation
```

Start a new Claude Code session, then run:

```text
/portal:setup
```

### Codex

```bash
codex plugin marketplace add spotify/portal-ai-plugins
codex
```

Open `/plugins`, install Spotify Portal, start a new task, and ask:

```text
Set up Spotify Portal for me.
```

### Cursor

Register this GitHub repository in the Cursor team marketplace, then install Spotify Portal from **Cursor Settings → Plugins**.

Cursor uses the shared Portal CLI workflows.

## Workflows

| Workflow | Purpose |
| --- | --- |
| `setup` | Configure Portal CLI authentication |
| `doctor` | Run read-only readiness diagnostics |
| `search` | Search the software catalog and technical documentation |
| `service` | Produce a concise operational service briefing |
| `actions` | Discover, inspect, preview, and safely invoke Portal actions |

Claude Code exposes the plugin skills directly under the Portal namespace:

```text
/portal:setup [instance-name or backend-url]
/portal:doctor [instance-name]
/portal:search <query>
/portal:service <service-name or entity-ref>
/portal:actions [action-id]
```

Codex and Cursor auto-discover the same workflows from the plugin skills.

## Portal CLI

Claude Code, Codex, and Cursor use the shared Portal CLI workflows.

The workflows invoke the upstream CLI through:

```bash
npx @spotify/portal-cli <command>
```

Setup verifies the required `auth`, `actions`, `owner`, `search`, and `service` commands before continuing.
