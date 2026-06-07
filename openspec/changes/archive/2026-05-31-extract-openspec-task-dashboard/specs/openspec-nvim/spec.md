# openspec.nvim Specification

## ADDED Requirements

### Requirement: Configurable Neovim plugin setup

The plugin SHALL expose `require("openspec").setup(opts)` for user configuration.

#### Scenario: Enable default commands and keymaps

- **WHEN** setup is called with no options
- **THEN** the plugin registers default commands for task summary, remaining tasks, all tasks, next task, and HTML dashboard
- **AND** the plugin registers default keymaps for the same actions.

#### Scenario: Disable default keymaps

- **WHEN** setup is called with `keymaps = false`
- **THEN** the plugin registers commands without default keymaps.

#### Scenario: Fallback setup command is available

- **WHEN** the plugin is loaded without an explicit config block
- **THEN** `:OpenSpecSetup` is available to register commands and default keymaps.

### Requirement: OpenSpec change discovery

The plugin SHALL discover active OpenSpec changes from the nearest `openspec/changes` directory.

#### Scenario: Current buffer is inside a change

- **WHEN** the current buffer path is under `openspec/changes/<change>/`
- **THEN** the plugin selects that change automatically.

#### Scenario: Multiple active changes are available

- **WHEN** the current buffer does not identify a single change
- **AND** multiple active changes with `tasks.md` exist
- **THEN** the plugin asks the user to select one via `vim.ui.select`.

### Requirement: Task progress parsing

The plugin SHALL parse OpenSpec `tasks.md` checklist items into task status, line number, section, and text.

#### Scenario: Parse default checkbox states

- **WHEN** `tasks.md` contains `- [ ]`, `- [x]`, `- [X]`, `- [/]`, or `- [-]`
- **THEN** the plugin classifies them as todo, done, done, work in progress, and skipped respectively.

#### Scenario: Compute next task

- **WHEN** parsed tasks include todo or work-in-progress items
- **THEN** the next task is the first todo or work-in-progress item in file order.

### Requirement: Task reading views

The plugin SHALL provide read-only views for OpenSpec task progress.

#### Scenario: Toggle summary view

- **WHEN** the task summary is opened
- **THEN** the plugin shows total progress, next task, and per-section progress in a floating window
- **AND** invoking the summary action again closes that floating window.

#### Scenario: Send tasks to quickfix

- **WHEN** the remaining task action is invoked
- **THEN** the plugin sends todo and work-in-progress tasks to quickfix with file and line locations.

#### Scenario: Open temporary HTML dashboard

- **WHEN** the HTML dashboard action is invoked
- **THEN** the plugin writes a temporary HTML file and opens it
- **AND** it does not write generated HTML into the project tree.
