# Extract OpenSpec task dashboard into a Neovim plugin

## Summary

Move the local Neovim OpenSpec task dashboard into this repository as a reusable `openspec.nvim` plugin.

The plugin should keep OpenSpec markdown artifacts as the source of truth and provide a Neovim reading/navigation layer for `tasks.md`: progress summary, remaining task lists, next-task navigation, and a temporary HTML dashboard.

## Motivation

The original implementation lived inside a personal Neovim config as `ctchen.openspec_tasks`. That made it useful locally but hard to reuse, test, document, or evolve into a general OpenSpec workflow tool.

Extracting it into a plugin creates a cleaner boundary:

- Neovim config owns key preference and plugin loading.
- `openspec.nvim` owns OpenSpec discovery, task parsing, task progress UI, and future OpenSpec artifact navigation.

## Public API impact

- Adds `require("openspec").setup(opts)`.
- Adds default commands:
  - `:OpenSpecTasksSummary`
  - `:OpenSpecTasks`
  - `:OpenSpecTasksAll`
  - `:OpenSpecTasksNext`
  - `:OpenSpecTasksHtml`
- Adds configurable default keymaps when `keymaps = true`.

## Non-goals

- Do not replace OpenSpec markdown files with generated HTML.
- Do not require Telescope, Trouble, or other UI plugins in v1.
- Do not mutate task checkbox state in v1.
- Do not implement schema-aware artifact navigation in v1.
