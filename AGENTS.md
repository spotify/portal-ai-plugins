# Spotify Portal AI Plugin

This repository packages Spotify Portal workflows for Claude Code, Codex, and Cursor.

## Repository structure

- `skills/` contains the canonical workflow instructions.
- `commands/` contains thin Claude Code command adapters.
- `.claude-plugin/`, `.codex-plugin/`, and `.cursor-plugin/` contain host manifests.
- `assets/` contains shared Portal branding and product imagery.
- `.claude-plugin/marketplace.json` exposes the repository as a Claude Code marketplace.

## Design rules

- Keep the plugin at the repository root while this repository contains only Portal; introduce `plugins/<name>/` only for a real multi-plugin marketplace.
- Keep the plugin identifier `portal` so Claude Code commands use the `/portal:<workflow>` namespace.
- Do not bundle a fixed Portal MCP URL. In Claude Code, derive it from the customer instance selected through the Portal CLI.
- Portal MCP is not currently supported in Codex or Cursor. Keep those hosts on CLI-only workflows and do not claim MCP readiness.
- Keep `doctor` read-only.
- Keep command files as thin delegates to the matching skill.
- Do not publish the bundled skills as standalone packages.
- Do not add release automation unless a tagged GitHub release or another distribution channel is explicitly planned.
- Preserve JSON output and dry-run safeguards when documenting Portal CLI operations.

## Validation

```bash
uv run --with pyyaml python \
  ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  .

claude plugin validate --strict .
```
