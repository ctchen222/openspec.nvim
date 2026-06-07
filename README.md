# openspec.nvim

OpenSpec task progress for Neovim.

`openspec.nvim` keeps OpenSpec markdown artifacts as the source of truth and adds a Neovim reading layer for OpenSpec changes: a quick task summary, a native workspace cockpit, and a temporary HTML change report.

## Current status

Prototype plugin. The first public surface focuses on OpenSpec task tracking. The code is intentionally small and dependency-free so the workflow can be refined before adding Telescope, Trouble, or schema-aware artifact navigation.

## Features

- Discover the nearest `openspec/changes` directory from the current buffer or cwd.
- Prefer the current `openspec/changes/<change>/tasks.md` when the cursor is already inside a change.
- Parse checkbox tasks:
  - `- [ ]` todo
  - `- [x]` / `- [X]` done
  - `- [/]`, `- [~]`, `- [>]` work in progress
  - `- [-]` skipped
- Show a larger, focused floating summary with total progress, next task, and the highest-priority sections that still have todo/WIP work.
- Generate a temporary dark-mode HTML change report from `proposal.md`, `design.md`, `specs/**/*.md`, and `tasks.md` without writing generated files into the project.
- Toggle the HTML report between dark and light mode from the report header without requiring JavaScript.
- Set a checkbox task status from an open `tasks.md` buffer.
- Show an OpenSpec control cockpit with artifact digest, Git context, local findings, and next recommended upstream action.
- Generate context packs from the selected/next task without driving OpenSpec lifecycle actions from inside Neovim.
- Keep OpenSpec artifacts as the source of truth while making terminal-side OpenSpec actions (apply/verify/archive) explicit and auditable.

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
| `<leader>ow` | Open workspace cockpit |
| `<leader>oh` | Open a temporary HTML change report |

Information ladder:

| Surface | Use it for |
| --- | --- |
| `<leader>os` | Explicit change selection, compact spec state, artifact readiness, task progress, next task, and top incomplete sections |
| `<leader>ow` / `:OpenSpecWorkspace` | Native Neovim cockpit with artifact digest, Git context, local findings, and next upstream action |
| `<leader>oh` | Full browser-readable proposal, design, spec delta, and tasks dossier |

`<leader>os` always asks which active change to summarize, even when only one
change with `tasks.md` exists. The summary is intentionally compact: it shows
local artifact readiness, spec delta count and names, task progress, the next
task, and the next upstream OpenSpec action to run outside Neovim.

The workspace cockpit is a digest, not a full artifact preview or picker. Use it
to decide what needs attention, then open the source artifact or HTML report for
complete proposal, design, spec delta, or task content.

Commands:

```vim
:OpenSpecTasksSummary
:OpenSpecTasksHtml
:OpenSpecTaskStatus done
:OpenSpecWorkspace
:OpenSpecTaskStart
:OpenSpecContext
:OpenSpecCurrent
```

Use `:OpenSpecTaskStatus {done|todo|wip|skipped} [line]` from an open `tasks.md`
buffer to update a task checkbox. When `[line]` is omitted, the command uses
the current cursor line. The command updates the buffer and leaves normal
Neovim write control to you.

`<leader>ow` opens the native workspace cockpit. Other workflow commands remain
explicit so task mutation and audit actions are deliberate:

- `:OpenSpecWorkspace` opens a scratch split workspace for the selected change.
- `:OpenSpecTaskStart [line]` marks the chosen task as WIP, then opens the workspace cockpit and local findings quickfix.
- `:OpenSpecContext [line]` opens a scratch Markdown context pack for terminal agents.
- `:OpenSpecCurrent` prints a lightweight current-change summary and the top recommendation.

Agent collaboration pattern:

- `:OpenSpecTaskStart` and `:OpenSpecWorkspace` keep task context local.
- `/opsx:apply <change>` or `$openspec-apply-change <change>` executes upstream implementation flow outside Neovim.
- `/opsx:verify <change>` and `/opsx:archive <change>` are recommended when tasks are complete and validation passes.
- Use `:OpenSpecContext` when you need a focused handoff buffer for terminal automation.

## Configuration

```lua
require("openspec").setup({
  commands = true,
  keymaps = true,
  mappings = {
    summary = "<leader>os",
    html = "<leader>oh",
    workspace = "<leader>ow",
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
    max_width = 120,
  },
  health = {
    validation = {
      enabled = true,
    },
  },
  context = {
    model_routing = {
      enabled = true,
      profiles = {
        {
          name = "Spec planning",
          model = "gpt-5.5",
          effort = "xhigh",
          command = "/model gpt-5.5 xhigh",
          use_for = "proposal, design, spec delta, task shaping, and scope decisions",
        },
        {
          name = "Task implementation",
          model = "gpt-5.4",
          effort = "high",
          command = "/model gpt-5.4 high",
          use_for = "code edits, focused tests, documentation updates, and small refactors",
        },
      },
      switch_rules = {
        "Start with the planning profile only while shaping proposal, design, spec, or tasks.",
        "Switch to the implementation profile before editing code, tests, or docs.",
        "Switch back to planning only when scope, requirements, or acceptance criteria are unclear.",
      },
    },
  },
})
```

`context.model_routing` is provider-neutral. `model`, `effort`, and `command`
are rendered as handoff text only; `openspec.nvim` does not switch external
agent sessions by itself. Set `enabled = false` to omit the section.

## Product direction

The long-term direction is to make Neovim an OpenSpec control plane: current
change awareness, local health and drift checks, worktree context, artifact search,
and AI collaboration context while OpenSpec markdown remains the source of
truth.

Roadmap phases:

- Build an OpenSpec-aware cockpit for current-change health and task visibility.
- Add artifact-quality checks, missing-file findings, and drift warnings before implementation.
- Make Git branch and worktree context visible from Neovim.
- Keep context packs focused on selected tasks and upstream commands.
- Add optional downstream search and archived-change awareness while staying in plugin scope.

See [docs/roadmap.md](docs/roadmap.md) for the full product roadmap,
[docs/ideas.md](docs/ideas.md) for backlog notes,
[docs/architecture.md](docs/architecture.md) for the current plugin boundary,
and [docs/release-checklist.md](docs/release-checklist.md) for
release-readiness criteria.

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
