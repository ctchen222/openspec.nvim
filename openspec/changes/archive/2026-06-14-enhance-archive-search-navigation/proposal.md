## Why

Archived changes are now visible from Neovim, but the result surface is still mostly passive text. Users need a read-only way to inspect archived context and jump directly to proposal, design, tasks, and spec artifacts without turning archive search into a lifecycle executor.

This change keeps upstream OpenSpec as the owner of archive/apply/verify/sync workflows while making `openspec.nvim` a faster navigation surface for both archived and active changes.

## What Changes

- Add buffer-local artifact shortcuts to archive search results:
  - `p` opens proposal.
  - `d` opens design.
  - `t` opens tasks.
  - `s` opens spec delta artifacts, using `vim.ui.select` when multiple specs exist.
  - `<Enter>` opens the selected archive detail or matched artifact depending on the current line.
  - `q` closes the read-only surface.
- Add the same `p/d/t/s` artifact shortcuts to the `<leader>os` summary buffer for the selected active change.
- Add read-only archive detail buffers for archived changes.
- Improve archive search rendering with key hints, artifact grouping, query snippets, query highlighting where possible, clearer empty states, and result caps.
- Preserve the public setup API and default keymaps.
- Do not add archive, unarchive, apply, verify, sync, or other lifecycle execution actions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-nvim`: Adds read-only archive search navigation, archive detail inspection, and summary artifact shortcuts while preserving upstream lifecycle boundaries.

## Impact

- Affected commands and UI:
  - `:OpenSpecArchiveSearch [query]`
  - `<leader>os` summary buffer behavior
  - New read-only archive detail buffer surface
- Affected implementation areas:
  - Archive discovery/search rendering
  - Buffer-local keymap installation
  - Artifact target resolution
  - Safe artifact opening from scratch buffers back into the source window
  - Summary buffer metadata
- Public API:
  - No setup API changes.
  - No default keymap changes.
  - No new external plugin dependencies.
