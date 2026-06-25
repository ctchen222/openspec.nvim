## MODIFIED Requirements

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

## ADDED Requirements

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
