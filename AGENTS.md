# Spotify Portal AI Plugin

This repository packages Spotify Portal workflows for Claude Code, Codex, and Cursor.

## Repository structure

- `skills/` contains the canonical Portal workflow instructions.
- `plugins/shunt/` contains the shunt plugin (Claude Code only for now): scripts, skills, hooks, and evals for routing I/O-heavy work to AiKA modes.
- `.claude-plugin/`, `.codex-plugin/`, and `.cursor-plugin/` contain host manifests.
- `assets/` contains shared Portal branding and product imagery.
- `.claude-plugin/marketplace.json` exposes the repository as a Claude Code marketplace.

## Design rules

- Keep the portal plugin at the repository root; additional plugins live under `plugins/<name>/` and are registered in `.claude-plugin/marketplace.json`. Move portal under `plugins/` only together with the other host manifests.
- Keep the plugin identifier `portal` so Claude Code skills use the `/portal:<workflow>` namespace.
- Keep `doctor` read-only.
- Keep each workflow canonical in `skills/`.
- Do not publish the bundled skills as standalone packages.
- Do not add release automation unless a tagged GitHub release or another distribution channel is explicitly planned.
- Preserve JSON output and dry-run safeguards when documenting Portal CLI operations.

## Validation

```bash
uv run --with pyyaml python \
  ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  .

claude plugin validate --strict .

# shunt hook + transport evals (no Portal access needed)
bash plugins/shunt/evals/run.sh
```
