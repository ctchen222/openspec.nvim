# openspec.nvim

OpenSpec task progress for Neovim.

`openspec.nvim` keeps OpenSpec markdown artifacts as the source of truth and adds a Neovim reading layer for `tasks.md`: progress summary, remaining-task navigation, quickfix lists, and a temporary HTML dashboard.

## Current status

Prototype plugin. The first public surface focuses on OpenSpec task tracking. The code is intentionally small and dependency-free so the workflow can be refined before adding Telescope, Trouble, schema-aware artifact navigation, or task mutation.

## Features

- Discover the nearest `openspec/changes` directory from the current buffer or cwd.
- Prefer the current `openspec/changes/<change>/tasks.md` when the cursor is already inside a change.
- Parse checkbox tasks:
  - `- [ ]` todo
  - `- [x]` / `- [X]` done
  - `- [/]`, `- [~]`, `- [>]` work in progress
  - `- [-]` skipped
- Show a toggleable floating summary with total progress, next task, and per-section progress.
- Populate quickfix with remaining tasks or all tasks.
- Jump to the next todo/WIP task.
- Generate a temporary HTML dashboard without writing generated files into the project.

## Installation

With `lazy.nvim` from a local checkout:

```lua
{
  dir = "/Users/ctchen/Development/project/openspec.nvim",
  name = "openspec.nvim",
  config = function()
    require("openspec").setup()
  end,
}
```

## Usage

Default keymaps:

| Key | Action |
| --- | --- |
| `<leader>os` | Toggle task summary |
| `<leader>ot` | Send remaining todo/WIP tasks to quickfix |
| `<leader>oa` | Send all tasks to quickfix |
| `<leader>on` | Jump to next todo/WIP task |
| `<leader>oh` | Open a temporary HTML dashboard |

Commands:

```vim
:OpenSpecSetup
:OpenSpecTasksSummary
:OpenSpecTasks
:OpenSpecTasksAll
:OpenSpecTasksNext
:OpenSpecTasksHtml
```

`:OpenSpecSetup` is a fallback command for plugin-manager setups that load the plugin without calling `require("openspec").setup()` in the config block.

## Configuration

```lua
require("openspec").setup({
  commands = true,
  keymaps = true,
  mappings = {
    summary = "<leader>os",
    remaining = "<leader>ot",
    all = "<leader>oa",
    next = "<leader>on",
    html = "<leader>oh",
  },
  tasks = {
    include_skipped_in_total = false,
    statuses = {
      todo = { " " },
      done = { "x", "X" },
      wip = { "/", "~", ">" },
      skipped = { "-" },
    },
  },
  ui = {
    border = "rounded",
    max_width = 100,
  },
})
```

## Roadmap ideas

- Telescope picker for active changes and tasks.
- Trouble integration for a richer task list view.
- OpenSpec artifact navigator for `proposal.md`, `design.md`, and spec deltas.
- `openspec status --json` integration when the CLI is available.
- Schema-aware discovery using OpenSpec config and custom schema metadata.
- Task toggling from the quickfix/dashboard view.
- Branch-to-change inference for common branch naming conventions.
- Project-wide overview of all active changes.
- Exportable HTML report with filters and richer section progress.

See [docs/ideas.md](docs/ideas.md) for a longer backlog, [docs/architecture.md](docs/architecture.md) for the current plugin boundary, and [docs/release-checklist.md](docs/release-checklist.md) for publish-readiness gates.

## Development

Run local checks:

```sh
make check
```

Generate helptags:

```sh
make helptags
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for the manual smoke test checklist and release criteria.
# openspec.nvim
