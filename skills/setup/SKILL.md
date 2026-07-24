---
name: setup
description: Set up, authenticate, and verify Spotify Portal for the current coding agent. Use when the user asks to install or connect Portal, authenticate the Portal CLI, select a Portal instance, configure the instance-specific Portal MCP endpoint in Claude Code, or verify CLI or supported MCP access.
---

# Set Up Spotify Portal

Set up the Portal CLI for every supported host. In Claude Code, then configure Portal MCP for the selected customer instance. Portal MCP is not currently supported in Codex or Cursor.

## Critical rules

1. Never ask the user to paste access tokens, authorization codes, or other credentials into chat.
2. Run `--help` before relying on a Portal CLI or host command or flag.
3. Prefer `--json` whenever the agent consumes command output.
4. Never assume the default authenticated Portal instance when more than one instance is listed. Ask the user which instance to use.
5. Configure Portal MCP only in Claude Code. Do not attempt Portal MCP setup in Codex or Cursor.
6. In Claude Code, inspect an existing MCP entry before changing it. If its URL differs from the selected Portal instance, show both URLs and ask before replacing it.
7. In Claude Code, CLI authentication and MCP OAuth are separate sessions. Completing CLI login does not prove MCP authentication succeeded.

## CLI invocation

Verify Node.js and npm:

```bash
node --version
npm --version
```

Run Portal CLI commands through the upstream package:

```bash
npx @spotify/portal-cli <command>
```

Inside a Portal source checkout, `npx` resolves the workspace-local build; elsewhere it fetches the published npm package.

## Setup workflow

Complete these steps in order.

### 1. Verify command discovery

```bash
npx @spotify/portal-cli --help
npx @spotify/portal-cli auth --help
```

The first command should list `auth`, `actions`, `owner`, `search`, and `service`. If they are absent, the resolved CLI build is too old for this workflow. Stop and report that a newer Portal CLI release is required.

### 2. Inspect existing instances

```bash
npx @spotify/portal-cli auth list
```

- Reuse an instance whose backend URL matches the user's target.
- If one instance exists and the user did not name a target, confirm it before continuing.
- If multiple instances exist, show their names and URLs and ask the user to choose.
- If no matching instance exists, obtain the Portal backend URL and a short instance name from the user.

### 3. Authenticate when needed

Run login only when the chosen instance is not already authenticated:

```bash
npx @spotify/portal-cli auth login --instance <instance-name> --backend-url <backend-url>
```

The command may open a browser. Let the user complete authentication there. If the environment cannot open a browser, inspect login help and use its no-browser flow. Never request credentials in chat.

### 4. Select and verify the instance

```bash
npx @spotify/portal-cli auth select --instance <instance-name>
npx @spotify/portal-cli auth show --instance <instance-name>
```

Do not continue unless `auth show` succeeds for the chosen instance.

### 5. Verify agent-safe CLI access

```bash
npx @spotify/portal-cli actions list --json
```

Success proves that the CLI can authenticate, reach the selected Portal instance, and read the user's available actions.

### 6. Configure the instance-specific MCP endpoint

If the current host is Codex or Cursor, do not configure Portal MCP. Report
that Portal MCP is not currently supported in that host, retain the verified
CLI setup, and skip step 7.

Build the MCP URL by removing any trailing slash from the selected backend URL and appending:

```text
/api/mcp-actions/v1
```

Inspect the supported syntax and any existing entry:

```bash
claude mcp add --help
claude mcp get portal
```

If no `portal` entry exists, add it at user scope:

```bash
claude mcp add --transport http --scope user portal <mcp-url>
```

If an existing entry points elsewhere, do not remove or overwrite it without explicit user authorization.

### 7. Verify MCP in a new session

MCP configuration is loaded at agent startup. Ask the user to start a new Claude Code session, then:

1. Confirm Portal MCP tools are visible.
2. Complete Portal OAuth in the browser if requested.
3. Make one harmless, read-only Portal call.
4. Report MCP ready only after the tool call succeeds.

A `401 Unauthorized` response from the bare endpoint before OAuth is expected and does not prove setup succeeded.

## Completion report

Report:

- CLI build source: workspace-local or published package
- selected instance name and backend URL
- CLI authentication: confirmed or blocked
- `actions list --json`: confirmed or blocked
- Portal MCP support: supported in Claude Code or not currently supported in Codex or Cursor
- MCP URL and host configuration in Claude Code: confirmed, blocked, or conflict found
- MCP read-only call in Claude Code: confirmed, blocked, or requires a new session
