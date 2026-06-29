## ADDED Requirements

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
