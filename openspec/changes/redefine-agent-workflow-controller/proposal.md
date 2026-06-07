## Why

`openspec.nvim` is a Neovim control surface. There is already substantial functionality in place, but two risks remain:

- Plugin behavior and the OpenSpec upstream CLI/skills ownership boundary are still overlapping.
- Existing phrasing and flow still hints at a local four-gate / agent loop pattern, which can mislead users into assuming lifecycle execution happens inside Neovim.

This change establishes `openspec.nvim` as:

- Readable, diagnosable, and handoff-ready.
- Not the owner of lifecycle control.
- Explicitly returning `propose / apply / verify / sync / archive` to upstream OpenSpec workflows.

## What Changes

- `workspace` state is now driven by OpenSpec CLI JSON when available, with local parser fallback when CLI is unavailable.
- Replaced local workflow-gate semantics in the workspace with practical `local health findings` and actionable `next upstream action` recommendations.
- `OpenSpecWorkspace` remains an in-editor information cockpit, providing:
  - Change identity, task progress, and artifact digest.
  - Git status, diff validation, and reference existence checks.
  - Quickfix-oriented findings with file anchors.
  - Recommended upstream actions (command + skill).
- `OpenSpecContext` is now an upstream-action context pack that aggregates selected task/artifact/Git/health signals and explicitly states it is not a lifecycle executor.
- `:OpenSpecTaskStatus` remains limited to writing `tasks.md` checkboxes only, as an explicit and reversible local mutation.

## Capabilities

### New / Modified capabilities
- `openspec.nvim`: Added/refined upstream-facing control surface capabilities (CLI-backed state, health checks, upstream recommendations, and context packs).
- `openspec.nvim`: Retains task overviews and handoff reports as decision entry points for both humans and AI.

### Removed / deprecated capabilities
- Do not add executable commands for `propose / apply / verify / sync / archive`.
- Do not treat `Task Binding / Preflight / Context / Audit` as lifecycle gates.
- Do not use project-local `openspec-agent-loop` as a core workflow precondition.

## Impact

- Change artifacts and tests:
  - `openspec/changes/redefine-agent-workflow-controller/*`
  - `lua/openspec/*` (CLI adapter, health evaluator, context and workspace views)
  - `docs/README/README.md` (control-boundary and command semantics)
  - `tests/*` (health checks, recommendation output, CLI-absent fallback)
- Non-breaking intent: keep the plugin dependency-free; fallback remains functional without CLI.
