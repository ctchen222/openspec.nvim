## ADDED Requirements

### Requirement: Model-enforced implementation launcher

The plugin SHALL provide an `OpenSpecImplement` workflow that starts a new agent implementation session with provider and model settings applied at launch time.

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
