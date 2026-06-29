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

#### Scenario: Current-context commands infer active change

- **WHEN** a current-context command is invoked from a buffer path under `openspec/changes/<change>/`
- **THEN** the plugin can select that change automatically.

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
- **THEN** the plugin asks the user to select an active change through `vim.ui.select`, even when only one active change exists
- **AND** it shows local artifact readiness, spec delta count and names, total progress, next task, recommended upstream action, and sections with remaining todo or work-in-progress tasks in a floating window
- **AND** invoking the summary action again closes that floating window.

#### Scenario: Open temporary HTML change report

- **WHEN** the HTML report action is invoked
- **THEN** the plugin writes a temporary HTML file with a concise overview and readable collapsible proposal, design, spec delta, and task sections
- **AND** the report opens in dark mode with a light/dark toggle
- **AND** it does not write generated HTML into the project tree.

### Requirement: Summary artifact shortcuts

The plugin SHALL provide buffer-local artifact shortcuts in the compact task summary for the selected active change.

#### Scenario: Show summary artifact key hint

- **WHEN** the task summary buffer is rendered for a selected active change
- **THEN** it shows a concise key hint for `p`, `d`, `t`, and `s` artifact navigation.

#### Scenario: Open active change artifacts by shortcut

- **WHEN** the task summary buffer is focused
- **AND** the user presses `p`, `d`, `t`, or `s`
- **THEN** the plugin opens the selected active change's proposal, design, tasks, or spec artifact respectively
- **AND** the summary floating window is closed after a successful open.

#### Scenario: Close summary after spec delta selection

- **WHEN** the selected active change has multiple spec delta artifacts
- **AND** the user presses `s` in the task summary buffer
- **AND** the user selects a target from the `vim.ui.select` dialog and it opens successfully
- **THEN** the plugin closes the summary floating window only after the selection completes.

#### Scenario: Notify missing active artifact

- **WHEN** the user requests an active change artifact that does not exist
- **THEN** the plugin notifies the user
- **AND** it does not create a new artifact file
- **AND** the summary window remains open.

#### Scenario: Preserve existing summary mapping behavior

- **WHEN** summary artifact shortcuts are installed
- **THEN** the existing configured summary mapping remains unchanged
- **AND** no new default keymaps or setup options are added.

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

### Requirement: Model-enforced implementation launcher

The plugin SHALL provide an `OpenSpecImplement` workflow that starts a new agent implementation session with provider and model settings applied at launch time, and SHALL scope the implementation context to the selected task or the entire change depending on the cursor position at invocation time.

#### Scenario: Launch Codex implementation profile

- **GIVEN** the user runs `:OpenSpecImplement codex profile=implementation`
- **WHEN** the user confirms the launch preview
- **THEN** the plugin SHALL start a new interactive Codex session
- **AND** the session SHALL use the model and effort resolved from the `implementation` profile
- **AND** the generated implementation context SHALL be made available to that session

#### Scenario: Override profile model from command arguments

- **GIVEN** a configured implementation profile
- **WHEN** the user runs `:OpenSpecImplement codex profile=implementation model=gpt-5.4 effort=high`
- **THEN** the explicit `model` and `effort` arguments SHALL override the profile values for that launch

#### Scenario: Context scopes agent to selected task

- **GIVEN** the user has positioned the cursor on a task line in `tasks.md`
- **WHEN** `OpenSpecImplement` generates the implementation context
- **THEN** the Allowed Scope section SHALL instruct the agent to implement only the selected task
- **AND** the Stop Conditions section SHALL include a condition to stop if the selected task scope would expand.

#### Scenario: Context scopes agent to whole change

- **GIVEN** `OpenSpecImplement` is invoked from outside `tasks.md` or from a non-task line in `tasks.md`
- **WHEN** `OpenSpecImplement` generates the implementation context
- **THEN** the Allowed Scope section SHALL instruct the agent to implement all tasks in the change in order
- **AND** the Stop Conditions section SHALL NOT include conditions that reference "the selected task"
- **AND** the Stop Conditions section SHALL include a condition to stop if scope needs expansion beyond the listed tasks
- **AND** the selected task SHALL remain nil through the launch path without substituting `parsed.next_task`.

### Requirement: Provider adapter model resolution

The plugin SHALL resolve provider, model, effort, and layout settings before launching an implementation session.

#### Scenario: Resolution precedence

- **GIVEN** command arguments, model profiles, default profiles, and provider defaults exist
- **WHEN** `OpenSpecImplement` prepares a launch
- **THEN** explicit command arguments SHALL take precedence over named profile values
- **AND** named profile values SHALL take precedence over default profile values
- **AND** default profile values SHALL take precedence over provider adapter defaults

#### Scenario: Configurable provider adapter

- **GIVEN** a provider such as `opencode` does not have verified built-in CLI model flags
- **WHEN** the provider is configured with a command template
- **THEN** `OpenSpecImplement` SHALL use the configured adapter template instead of assuming hard-coded flags

### Requirement: Launch preview and cancellation

The plugin SHALL show a Neovim preview confirmation before starting a new provider session.

#### Scenario: User cancels preview

- **GIVEN** `OpenSpecImplement` has generated context and resolved launch settings
- **WHEN** the preview is shown
- **AND** the user cancels
- **THEN** the plugin SHALL NOT start Codex, Claude, opencode, tmux, external terminal, or Neovim terminal launch commands

#### Scenario: User confirms preview

- **GIVEN** `OpenSpecImplement` has generated context and resolved launch settings
- **WHEN** the preview is shown
- **AND** the user confirms
- **THEN** the plugin SHALL launch the selected provider in the selected display surface

### Requirement: Context handoff through temporary file

The plugin SHALL hand generated implementation context to the new session through a temporary context file or provider-safe equivalent.

#### Scenario: Large context launch

- **GIVEN** the generated implementation context is too large to safely pass as a shell argument
- **WHEN** `OpenSpecImplement` launches the provider session
- **THEN** the plugin SHALL avoid relying on a single long shell argument for the full context body
- **AND** the launched session SHALL still receive instructions to use the generated implementation context

### Requirement: Display surface selection

The plugin SHALL support tmux, Neovim terminal, external terminal, and copy-only display surfaces for implementation sessions.

#### Scenario: tmux auto layout on wide pane

- **GIVEN** the user is inside tmux
- **AND** the current pane is wide enough for a side-by-side agent session
- **WHEN** `layout=auto` is used
- **THEN** the plugin SHALL open the provider session in a right tmux pane

#### Scenario: tmux auto layout on narrow pane

- **GIVEN** the user is inside tmux
- **AND** the current pane is too narrow for a side-by-side agent session
- **WHEN** `layout=auto` is used
- **THEN** the plugin SHALL open the provider session in a bottom tmux pane

#### Scenario: no tmux fallback

- **GIVEN** the user is not inside tmux
- **WHEN** `layout=auto` is used
- **THEN** the plugin SHALL open the provider session in a Neovim right terminal split by default

#### Scenario: configured non-tmux surface

- **GIVEN** the user has configured a non-tmux display surface
- **WHEN** `OpenSpecImplement` launches outside tmux
- **THEN** the plugin SHALL use the configured surface such as Neovim bottom split, external terminal, or copy-only output

### Requirement: OpenSpecContext model guidance boundary

The plugin SHALL distinguish model guidance in generated context from model enforcement in launched sessions.

#### Scenario: existing session receives copied context

- **GIVEN** the user copies `OpenSpecContext` output into an already-running Codex or Claude conversation
- **WHEN** the output includes model routing information
- **THEN** the output SHALL NOT claim that the existing session will automatically switch models
- **AND** the output SHALL explain that guaranteed model selection requires launching through `OpenSpecImplement` or manually switching the existing session model

### Requirement: Claude launch setting validation

The plugin SHALL validate the resolved Claude model before launching a Claude
implementation session.

#### Scenario: Claude alias model launches

- **GIVEN** the user runs `:OpenSpecImplement claude model=opus`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL allow the launch preview to be shown
- **AND** the rendered Claude command SHALL include `--model opus`.

#### Scenario: Full Claude model id launches

- **GIVEN** the user runs `:OpenSpecImplement claude model=claude-opus-4-8`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL allow the launch preview to be shown.

#### Scenario: Non-Claude model is rejected

- **GIVEN** the user runs `:OpenSpecImplement claude model=gpt-5.4`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL reject the launch before starting any provider
- **AND** the plugin SHALL NOT open tmux, Neovim terminal, external terminal, or
  copy-only launch output
- **AND** the error SHALL explain that the model is not a recognized Claude
  model and recommend passing an explicit `model=opus`.

#### Scenario: Default profile codex model does not bleed into Claude

- **GIVEN** the default profile resolves the Claude model to a codex model such
  as `gpt-5.4`
- **WHEN** `OpenSpecImplement` prepares a Claude launch with no explicit
  `model=` argument
- **THEN** the plugin SHALL reject the launch before starting any provider
- **AND** the error SHALL recommend passing an explicit Claude model.

### Requirement: Claude adapter default command flags

The plugin SHALL render the built-in Claude command without flags the upstream
`claude` CLI does not accept, while keeping provider command configuration
overridable.

#### Scenario: Built-in Claude command omits effort flag

- **GIVEN** the user runs `:OpenSpecImplement claude model=opus effort=high`
- **WHEN** the Claude launch command is rendered with the built-in adapter
- **THEN** the command SHALL include `--model opus`
- **AND** the command SHALL NOT include an `--effort` flag.

#### Scenario: Custom Claude adapter can restore an effort flag

- **GIVEN** the Claude provider is configured with a `command_template`
  containing an `{effort_flag}` token and an `effort_flag` value
- **WHEN** the Claude launch command is rendered
- **THEN** the command SHALL apply the configured effort flag.

