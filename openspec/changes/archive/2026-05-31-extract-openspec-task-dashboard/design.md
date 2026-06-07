# Design

## Architecture

The plugin is split into small Lua modules:

- `openspec.config`: default options, setup merge, status lookup.
- `openspec.discovery`: nearest OpenSpec root lookup, active change scanning, current-buffer change detection.
- `openspec.tasks`: `tasks.md` checkbox parsing and progress aggregation.
- `openspec.ui`: floating summary and quickfix presentation.
- `openspec.html`: temporary read-only HTML dashboard.
- `openspec.init`: public commands, keymaps, and orchestration.

## Data flow

1. A command or keymap calls `require("openspec").summary()` or a related action.
2. The plugin finds the nearest `openspec/changes` directory from the current buffer or cwd.
3. If the current buffer is inside `openspec/changes/<change>/`, that change is selected.
4. Otherwise, active changes with `tasks.md` are listed through `vim.ui.select`.
5. `tasks.md` is parsed into sections, task rows, counts, progress percentage, and next todo/WIP task.
6. The selected action renders the parsed model into a floating window, quickfix list, cursor jump, or temp HTML file.

## Compatibility

The v1 parser targets the default OpenSpec `tasks.md` checklist convention:

- `- [ ]` todo
- `- [x]` / `- [X]` done
- `- [/]`, `- [~]`, `- [>]` work in progress
- `- [-]` skipped

Status characters are configurable through `setup()` to support local conventions without changing parser code.

## Future extension points

- Add Telescope and Trouble adapters without making them hard dependencies.
- Read OpenSpec config/schema metadata to discover non-default artifact names.
- Integrate `openspec status --json` when available.
- Add task mutation as an opt-in command after the read-only workflow is stable.

## Product roadmap

The broader product direction is captured in [roadmap.md](roadmap.md).

That roadmap reframes `openspec.nvim` from a task dashboard into a Neovim control
surface for OpenSpec spec-driven development:

- Phase 0: finish and harden the current read-only extraction.
- Phase 1: add project-wide situational awareness and a current-change workspace.
- Phase 2: connect tasks to artifacts and OpenSpec validation.
- Phase 3: generate artifact-grounded AI collaboration context.
- Phase 4: add explicit, safe task mutation and diff-to-task audit.
- Phase 5: add optional UI integrations, reporting, and archive awareness.

The extraction in this change remains the first slice. Later roadmap phases
should be proposed as separate OpenSpec changes instead of expanding this v1
change indefinitely.
