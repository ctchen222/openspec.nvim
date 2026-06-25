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

The plugin SHALL launch Codex with an active OpenSpec implementation instruction
and SHALL apply resolved Codex model and effort settings before launch.

#### Scenario: Codex launch starts OpenSpec apply workflow

- **GIVEN** the user runs `:OpenSpecImplement codex model=gpt-5.5 effort=high`
- **WHEN** the user confirms the launch preview
- **THEN** the initial Codex prompt SHALL instruct Codex to use
  `/opsx:apply <change>` for the selected OpenSpec change
- **AND** the prompt SHALL include the temporary implementation context file
  path
- **AND** the prompt SHALL tell Codex to treat that file as the source of truth
  for the session
- **AND** the prompt SHALL tell Codex to start implementation without waiting
  for another user confirmation.

#### Scenario: Codex apply prompt includes verification

- **GIVEN** `OpenSpecImplement` has generated the initial Codex prompt
- **WHEN** the prompt is rendered
- **THEN** it SHALL include `make check`
- **AND** it SHALL include `openspec validate --all --strict`
- **AND** it SHALL tell Codex to report blocked state instead of expanding scope
  when verification cannot pass.

#### Scenario: Codex effort is passed through supported configuration

- **GIVEN** the user runs `:OpenSpecImplement codex model=gpt-5.5 effort=high`
- **WHEN** the Codex launch command is rendered
- **THEN** the command SHALL include `--model gpt-5.5`
- **AND** the command SHALL include a Codex configuration override equivalent to
  `model_reasoning_effort = "high"`
- **AND** the command SHALL NOT silently ignore the resolved effort value.

#### Scenario: Custom Codex template cannot drop the implementation instruction

- **GIVEN** the Codex provider is configured with a custom command template
- **AND** the template does not include a prompt-capable token such as
  `{initial_prompt}` or `{context_prompt}`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL reject the launch before starting Codex
- **AND** the error SHALL explain that the Codex template cannot receive the
  OpenSpec apply instruction.

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

### Requirement: Codex goal handoff

The plugin SHALL provide an opt-in Codex goal handoff mode for
`OpenSpecImplement` implementation launches.

#### Scenario: Launch Codex with goal handoff

- **GIVEN** the user runs `:OpenSpecImplement codex goal=auto`
- **WHEN** the user confirms the launch preview
- **THEN** the plugin SHALL launch a new interactive Codex session
- **AND** the initial Codex instruction SHALL use a generated `/goal` objective
- **AND** the generated `/goal` objective SHALL instruct Codex to use the
  OpenSpec apply command for the selected change
- **AND** the generated goal SHALL reference the temporary implementation
  context file
- **AND** the generated goal SHALL include completion criteria and verification
  commands.

#### Scenario: Preserve default non-goal behavior

- **GIVEN** the user runs `:OpenSpecImplement codex`
- **WHEN** no goal mode is configured by command arguments or profiles
- **THEN** the plugin SHALL use the modified model-enforced implementation
  launcher behavior
- **AND** the plugin SHALL NOT generate a `/goal` instruction.

#### Scenario: Copy goal for manual paste

- **GIVEN** the user runs `:OpenSpecImplement codex goal=copy`
- **WHEN** the user confirms the launch preview
- **THEN** the plugin SHALL copy the generated `/goal` command for manual paste
- **AND** the provider launch command SHALL continue to use the normal
  implementation instruction that invokes the OpenSpec apply command.

#### Scenario: Non-Codex provider rejects goal handoff

- **GIVEN** the user runs `:OpenSpecImplement claude goal=auto`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL reject the launch before starting any provider
  process
- **AND** the error SHALL explain that goal handoff is supported only for Codex.

### Requirement: Goal mode resolution

The plugin SHALL resolve goal handoff mode using the same precedence model as
provider launch settings.

#### Scenario: Goal mode precedence

- **GIVEN** command arguments, model profiles, default profiles, implementation
  defaults, and provider defaults exist
- **WHEN** `OpenSpecImplement` prepares a launch
- **THEN** explicit command goal mode SHALL take precedence over named profile
  goal mode
- **AND** named profile goal mode SHALL take precedence over default profile goal
  mode
- **AND** default profile goal mode SHALL take precedence over implementation
  default goal mode
- **AND** implementation default goal mode SHALL take precedence over provider
  default goal mode.

#### Scenario: Unsupported goal mode

- **GIVEN** the user runs `:OpenSpecImplement codex goal=always`
- **WHEN** arguments are parsed
- **THEN** the plugin SHALL reject the command
- **AND** the error SHALL list the supported goal modes.

### Requirement: Goal objective safety

The plugin SHALL generate bounded goal objectives that keep large OpenSpec
context in the existing temporary context file.

#### Scenario: Goal references context file

- **GIVEN** `OpenSpecImplement` has generated implementation context
- **WHEN** goal handoff is enabled
- **THEN** the full implementation context SHALL be written to a temporary file
- **AND** the generated goal SHALL reference that file path
- **AND** the generated goal SHALL NOT inline the full context body.

#### Scenario: Goal objective is too long

- **GIVEN** the generated goal objective exceeds Codex goal length limits
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL fail before launching a provider session
- **AND** the error SHALL explain that the goal objective is too long.

#### Scenario: Goal includes stop conditions

- **GIVEN** goal handoff is enabled
- **WHEN** the goal objective is generated
- **THEN** it SHALL instruct Codex to stop and ask for human input when
  implementation requires scope expansion, missing requirements, unrelated
  dirty files, failed verification, or unsafe repository state.

### Requirement: Completed implementation launch guard

The plugin SHALL prevent `OpenSpecImplement` from launching an implementation
provider when the selected implementation target is already complete.

#### Scenario: Selected task is already done

- **GIVEN** the user invokes `OpenSpecImplement` from a `tasks.md` checkbox line
  whose status is `done`
- **WHEN** `OpenSpecImplement` evaluates the launch target
- **THEN** the plugin SHALL NOT launch the provider session
- **AND** the plugin SHALL notify that the selected task is already done.

#### Scenario: Selected task is skipped

- **GIVEN** the user invokes `OpenSpecImplement` from a `tasks.md` checkbox line
  whose status is `skipped`
- **WHEN** `OpenSpecImplement` evaluates the launch target
- **THEN** the plugin SHALL NOT launch the provider session
- **AND** the plugin SHALL notify that the selected task is skipped.

#### Scenario: Whole change is complete

- **GIVEN** the user invokes `OpenSpecImplement` without selecting an incomplete
  task
- **AND** OpenSpec status reports the change as complete
- **WHEN** `OpenSpecImplement` evaluates the launch target
- **THEN** the plugin SHALL NOT launch the provider session
- **AND** the plugin SHALL notify that implementation is complete and recommend
  verification before archive.

#### Scenario: Incomplete target still launches

- **GIVEN** the user invokes `OpenSpecImplement` for a `todo` task, a `wip` task,
  or an incomplete whole change
- **WHEN** `OpenSpecImplement` evaluates the launch target
- **THEN** the plugin SHALL continue through the existing implementation launch
  flow.

### Requirement: Codex launch setting validation

The plugin SHALL validate Codex model and effort settings before launching a
Codex implementation session.

#### Scenario: Valid Codex model and effort launch

- **GIVEN** the user runs `:OpenSpecImplement codex model=gpt-5.5 effort=high`
- **AND** the Codex model catalog includes `gpt-5.5`
- **AND** `gpt-5.5` supports `high` reasoning effort
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL allow the launch preview to be shown
- **AND** the rendered Codex command SHALL apply the model selection
- **AND** the rendered Codex command SHALL apply the reasoning effort selection.

#### Scenario: Invalid Codex model is rejected

- **GIVEN** the user runs
  `:OpenSpecImplement codex model=gpt-5.3-codex-spark effort=high`
- **AND** the Codex model catalog does not include `gpt-5.3-codex-spark`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL reject the launch before starting Codex
- **AND** the plugin SHALL NOT open tmux, Neovim terminal, external terminal, or
  copy-only launch output
- **AND** the error SHALL explain that the model is not available in the Codex
  model catalog.

#### Scenario: Invalid Codex effort is rejected

- **GIVEN** the user runs `:OpenSpecImplement codex model=gpt-5.5 effort=ultra`
- **AND** the Codex model catalog says `gpt-5.5` does not support `ultra`
- **WHEN** `OpenSpecImplement` prepares the launch
- **THEN** the plugin SHALL reject the launch before starting Codex
- **AND** the error SHALL list the supported reasoning effort values for the
  selected model.

#### Scenario: Codex catalog unavailable fails closed

- **GIVEN** the Codex model catalog cannot be loaded or parsed
- **WHEN** `OpenSpecImplement` prepares a Codex launch with a resolved model or
  effort
- **THEN** the plugin SHALL reject the launch before starting Codex
- **AND** the error SHALL explain that launch settings could not be verified.

### Requirement: Goal preview and fallback

The plugin SHALL make goal handoff visible before launch and provide a fallback
when automatic slash-command handoff is not reliable.

#### Scenario: Preview includes goal details

- **GIVEN** goal handoff is enabled
- **WHEN** the launch preview is shown
- **THEN** the preview SHALL show the resolved goal mode
- **AND** the preview SHALL show a concise goal objective summary.

#### Scenario: Cancelled goal launch has no side effects

- **GIVEN** goal handoff is enabled
- **WHEN** the launch preview is cancelled
- **THEN** the plugin SHALL NOT start a provider process
- **AND** the plugin SHALL NOT copy a `/goal` command to the clipboard.

#### Scenario: Auto goal copies fallback

- **GIVEN** the user runs `:OpenSpecImplement codex goal=auto`
- **WHEN** the user confirms the launch preview
- **THEN** the plugin SHALL make the generated `/goal` command available as a
  copy fallback
- **AND** the plugin SHALL notify the user if the fallback copy fails.
