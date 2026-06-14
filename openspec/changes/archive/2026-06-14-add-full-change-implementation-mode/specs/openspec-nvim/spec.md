## MODIFIED Requirements

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
