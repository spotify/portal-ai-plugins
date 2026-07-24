<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/portal-wordmark-light.svg">
    <img src="assets/portal-wordmark-dark.svg" alt="Spotify Portal for Backstage" width="420">
  </picture>
</p>

<p align="center">
  Set up, diagnose, search, and operate Spotify Portal from Claude Code, Codex, and Cursor.
</p>

## Highlights

- Set up the Portal CLI and, in Claude Code, the selected customer's Portal MCP endpoint.
- Diagnose plugin, CLI, authentication, action, and supported MCP readiness without changing state.
- Search the software catalog and technical documentation using natural language.
- Build concise service briefings covering ownership, health, incidents, and documentation.
- Discover and safely invoke Portal actions with help, dry-run, and confirmation safeguards.

## Overview

[Spotify Portal for Backstage](https://backstage.spotify.com/docs/portal) is Spotify's managed internal developer portal. This plugin gives coding agents focused workflows for the Portal CLI. Claude Code can additionally configure Portal MCP using the customer-specific backend selected during authentication.

The plugin intentionally does not bundle a fixed `.mcp.json`. Each Portal customer has a different backend URL, so the Claude Code setup workflow derives `<backend-url>/api/mcp-actions/v1` from the selected CLI instance. Portal MCP is not currently supported in Codex or Cursor.

The workflow skills are bundled as plugin behavior. They are not published or installed as standalone skill packages.

## Installation

This repository is private, so GitHub credentials must be authorized for the Spotify organization.

### Claude Code

```bash
claude plugin marketplace add spotify/portal-ai-plugins
claude plugin install portal@portal
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

Register this private GitHub repository in the Cursor team marketplace, then install Spotify Portal from **Cursor Settings → Plugins**.

Cursor uses the shared Portal CLI workflows. Portal MCP is not currently supported in Cursor.

## Workflows

| Workflow | Purpose |
| --- | --- |
| `setup` | Configure Portal CLI authentication and, in Claude Code, tenant-specific MCP access |
| `doctor` | Run read-only readiness diagnostics |
| `search` | Search the software catalog and technical documentation |
| `service` | Produce a concise operational service briefing |
| `actions` | Discover, inspect, preview, and safely invoke Portal actions |

Claude Code exposes the workflows as slash commands:

```text
/portal:setup [instance-name or backend-url]
/portal:doctor [instance-name]
/portal:search <query>
/portal:service <service-name or entity-ref>
/portal:actions [action-id]
```

Codex and Cursor auto-discover the same workflows from the plugin skills.

## Portal CLI and MCP

| Client | Portal CLI | Portal MCP |
| --- | --- | --- |
| Claude Code | Supported | Supported through tenant-specific setup |
| Codex | Supported | Not currently supported |
| Cursor | Supported | Not currently supported |

The workflows invoke the upstream CLI through:

```bash
npx @spotify/portal-cli <command>
```

Setup verifies the required `auth`, `actions`, `owner`, `search`, and `service` commands before continuing. In Claude Code, CLI authentication and MCP OAuth remain separate sessions; MCP is only reported ready after a real read-only tool call succeeds.
