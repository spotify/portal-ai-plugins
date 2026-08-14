# Spotify Portal AI Plugins

Bring [Spotify Portal](https://portal.spotify.com) into Claude Code, Codex, and Cursor.

This plugin provides focused workflows for the
[Portal CLI](https://www.npmjs.com/package/@spotify/portal-cli): set up
authentication, search your software catalog, build service briefings, run
diagnostics, and invoke Portal actions.

## Highlights

- Set up the Portal CLI for your current coding-agent environment.
- Run read-only diagnostics to verify plugin, CLI, authentication, and action readiness.
- Search the software catalog and technical documentation using natural language queries.
- Generate concise service briefings with available ownership, health, incident, and documentation details.
- Discover and safely invoke Portal actions with built-in help, dry-run, and confirmation safeguards.

The marketplace also ships **shunt** (Claude Code only for now): a plugin that routes I/O-heavy agent work — bulk file reads and boilerplate generation — to AiKA modes running cheaper worker models, via the Portal CLI actions registry. See [`plugins/shunt/README.md`](plugins/shunt/README.md).

## Installation

### Claude Code

```bash
claude plugin marketplace add spotify/portal-ai-plugins
claude plugin install portal@portal
claude plugin install shunt@portal   # optional: token-saving AiKA delegation
```

Start a new session and run:

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

Register the [spotify/portal-ai-plugins](https://github.com/spotify/portal-ai-plugins)
repository in your Cursor team marketplace, then install Spotify Portal from
**Cursor Settings → Plugins**.

## Workflows

| Workflow | Purpose |
| --- | --- |
| `setup` | Configure Portal CLI authentication |
| `doctor` | Run read-only readiness diagnostics |
| `search` | Search the software catalog and technical documentation |
| `service` | Produce a concise operational service briefing |
| `actions` | Discover, inspect, preview, and safely invoke Portal actions |
| `feedback` | Submit feedback about the Portal CLI to the Portal team |

## Portal CLI

The workflows invoke the upstream CLI through:

```bash
npx @spotify/portal-cli <command>
```

Setup verifies the required `auth`, `actions`, `owner`, `search`, and `service`
commands before proceeding.
