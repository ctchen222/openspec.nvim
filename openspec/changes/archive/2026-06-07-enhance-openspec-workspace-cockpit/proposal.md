## Why

`<leader>os` is intentionally fast and compact, while `<leader>oh` opens the
full browser-readable OpenSpec dossier. Users still need a Neovim-native middle
layer that answers:

- which change am I looking at?
- what task and artifact context matters next?
- is the local editor/Git/OpenSpec state suspicious?
- which upstream OpenSpec action should I run outside Neovim?

The original archived version of this change described the workspace as a
four-gate workflow view. That no longer matches this project. OpenSpec upstream
owns propose/apply/verify/sync/archive, and `openspec.nvim` should be a control
surface only.

## What Changes

- Reframe `:OpenSpecWorkspace` as the middle layer between compact task summary
  and full HTML report.
- Keep the artifact digest: proposal summary, design/spec/tasks presence, spec
  delta count, change-relative paths, and task sections needing attention.
- Replace old workflow-gate wording with local health findings and upstream
  recommendations.
- Keep Git context, selected task, findings, quickfix routing, and next action
  visible in the workspace.
- Keep the workspace as a dependency-free Neovim scratch surface. It does not
  open a browser and does not write generated reports into the project tree.
- Preserve `<leader>os` as the quick task summary and `<leader>oh` as the full
  HTML report.

## Capabilities

### Modified Capabilities

- `openspec-nvim`: refine the Neovim-native workspace cockpit as an artifact
  digest and local-health surface, not a workflow-gate executor.
- `openspec-nvim`: keep the workspace keymap and command as the first-class
  in-editor middle layer for OpenSpec changes.

### Removed / Deprecated Semantics

- Do not describe the workspace as a four-gate workflow timeline.
- Do not show `Task Binding / Preflight / Context / Audit` as lifecycle gates.
- Do not imply that workspace findings approve implementation, verification, or
  archive. They only surface local evidence and recommend upstream actions.

## Impact

- Affected modules: `openspec.ui`, `openspec.artifacts`, `openspec.health`,
  `openspec.init`, `openspec.config`, tests, docs, and helptags.
- Public setup API keeps `mappings.workspace`.
- Default keymaps keep `<leader>ow` for workspace while summary and HTML remain
  stable.
- No external Neovim plugin, browser, embedding, hosted LLM, Telescope, or
  Trouble dependency is introduced.
- OpenSpec markdown artifacts remain the source of truth.
