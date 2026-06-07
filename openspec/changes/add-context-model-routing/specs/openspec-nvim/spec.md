## MODIFIED Requirements

### Requirement: Upstream skill context pack

The plugin SHALL generate a context pack that helps a user invoke upstream OpenSpec skills or commands.

#### Scenario: Build context for upstream action

- **WHEN** the user invokes `:OpenSpecContext`
- **THEN** the generated buffer includes selected change, selected task, artifact excerpts, local findings, validation state, Git state, and suggested upstream action.

#### Scenario: Include model routing guidance

- **WHEN** model routing is enabled for context packs
- **THEN** the generated buffer includes ordered model profiles, usage guidance, and switch rules for planning, implementation, and verification work.

#### Scenario: Disable model routing guidance

- **WHEN** model routing is disabled in setup configuration
- **THEN** the generated context pack omits model routing guidance.

#### Scenario: Context does not own task completion

- **WHEN** a context pack is generated
- **THEN** it does not claim `openspec.nvim` owns apply/verify/sync/archive, task-completion automation, model activation, or agent-session control.
