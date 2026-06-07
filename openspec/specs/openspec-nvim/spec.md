# openspec.nvim Specification

## Purpose

Provide a dependency-free Neovim interface for reading OpenSpec change progress and artifact context while keeping OpenSpec markdown artifacts as the source of truth.
## Requirements
### Requirement: Configurable Neovim plugin setup

The plugin SHALL expose `require("openspec").setup(opts)` for user configuration.

#### Scenario: Enable default commands and keymaps

- **WHEN** setup is called with no options
- **THEN** the plugin registers default commands for task summary and HTML change report
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
- **THEN** the plugin shows total progress, next task, and sections with remaining todo or work-in-progress tasks in a floating window
- **AND** invoking the summary action again closes that floating window.

#### Scenario: Open temporary HTML change report

- **WHEN** the HTML report action is invoked
- **THEN** the plugin writes a temporary HTML file with a concise overview and readable collapsible proposal, design, spec delta, and task sections
- **AND** the report opens in dark mode with a light/dark toggle
- **AND** it does not write generated HTML into the project tree.

### Requirement: Neovim-native workspace cockpit
The plugin SHALL provide a Neovim-native workspace cockpit for the selected
OpenSpec change that sits between the compact task summary and the full HTML
change report.

#### Scenario: Open workspace cockpit
- **WHEN** the user invokes `:OpenSpecWorkspace`
- **THEN** the plugin opens a Neovim workspace surface for the selected change
- **AND** the surface shows change identity, task progress, selected task,
  artifact digest, local health findings, Git context, and recommended upstream
  OpenSpec action.

#### Scenario: Stay inside Neovim
- **WHEN** the workspace cockpit is opened
- **THEN** the plugin does not open a browser
- **AND** it does not write generated report files into the project tree.

#### Scenario: Preserve existing change selection behavior
- **WHEN** the current buffer is inside an active OpenSpec change
- **THEN** the workspace cockpit uses that change automatically.
- **WHEN** multiple active changes are available and no single current change is
  inferred
- **THEN** the workspace cockpit asks the user to select one through the
  existing selection flow.

### Requirement: Workspace artifact digest
The plugin SHALL include an artifact digest in the workspace cockpit so users
can decide which OpenSpec artifact to inspect next without opening the full
HTML report.

#### Scenario: Show artifact presence and paths
- **WHEN** the workspace cockpit renders for a selected change
- **THEN** it shows whether proposal, design, tasks, and spec delta artifacts
  are present
- **AND** it shows their change-relative paths when available.

#### Scenario: Show concise proposal and spec context
- **WHEN** proposal or spec delta artifacts are present
- **THEN** the workspace cockpit shows a concise proposal summary or excerpt
- **AND** it shows the count and names of spec delta files.

#### Scenario: Show task sections needing attention
- **WHEN** parsed tasks contain todo or work-in-progress work
- **THEN** the workspace cockpit shows the task sections that still need
  attention with done, todo, and work-in-progress counts.

#### Scenario: Keep full artifact reading in the HTML report
- **WHEN** the user needs complete proposal, design, spec delta, or task content
- **THEN** the workspace cockpit points to the HTML report or source artifact
  paths instead of duplicating the full artifact bodies.

### Requirement: Workspace default mapping
The plugin SHALL expose a configurable default keymap for the workspace cockpit
without changing the existing summary and HTML report mappings.

#### Scenario: Register workspace mapping by default
- **WHEN** `require("openspec").setup()` is called with default options
- **THEN** the plugin registers a workspace mapping for `:OpenSpecWorkspace`
- **AND** the default mapping is `<leader>ow`.

#### Scenario: Configure workspace mapping
- **WHEN** setup is called with `mappings.workspace = "<custom>"`
- **THEN** the plugin uses the custom mapping for the workspace cockpit.

#### Scenario: Disable workspace mapping with keymaps option
- **WHEN** setup is called with `keymaps = false`
- **THEN** the plugin does not register the workspace mapping
- **AND** `:OpenSpecWorkspace` remains available as a command.

#### Scenario: Preserve summary and HTML mappings
- **WHEN** the workspace mapping is enabled
- **THEN** the existing summary and HTML mappings remain bound to their
  configured values.

### Requirement: Upstream OpenSpec workflow boundary
The plugin SHALL treat upstream OpenSpec CLI and generated skills as the owner
of change lifecycle automation.

#### Scenario: Recommend upstream lifecycle action
- **WHEN** a selected change has remaining tasks
- **THEN** the plugin recommends an upstream apply action instead of launching
  or implementing an agent loop.

#### Scenario: Recommend verification or archive
- **WHEN** a selected change has all tasks complete
- **THEN** the plugin recommends upstream verification and archive actions.

#### Scenario: Avoid duplicate lifecycle commands
- **WHEN** setup registers default commands
- **THEN** the plugin does not register commands that replace upstream propose,
  apply, verify, sync, or archive workflows.

### Requirement: CLI-backed OpenSpec state
The plugin SHALL prefer structured OpenSpec CLI state when the CLI is available
and SHALL degrade to local parsing when it is unavailable.

#### Scenario: CLI state is available
- **WHEN** `openspec list --json` and `openspec status --change <name> --json`
  succeed
- **THEN** the workspace uses the CLI-reported progress and artifact readiness.

#### Scenario: CLI is unavailable
- **WHEN** the OpenSpec CLI cannot be executed
- **THEN** the workspace still renders local task and artifact information
- **AND** it reports a non-blocking health finding explaining that CLI state is
  unavailable.

### Requirement: Local health findings
The plugin SHALL report local editor health findings without treating them as
a second lifecycle state model.

#### Scenario: Report local findings
- **WHEN** the workspace is rendered
- **THEN** findings are grouped by OpenSpec state, artifact state, Git state,
  and editor selection where applicable.

#### Scenario: Route findings to quickfix
- **WHEN** findings include source artifact paths
- **THEN** the plugin can publish them to quickfix entries.

### Requirement: Upstream skill context pack
The plugin SHALL generate a context pack that helps a user invoke upstream
OpenSpec skills or commands.

#### Scenario: Build context for upstream action
- **WHEN** the user invokes `:OpenSpecContext`
- **THEN** the generated buffer includes selected change, selected task,
  artifact excerpts, local findings, validation state, Git state, and suggested
  upstream action.

#### Scenario: Context does not own task completion
- **WHEN** a context pack is generated
- **THEN** it does not claim that `openspec.nvim` owns apply, verify, sync,
  archive, or task-completion automation.
