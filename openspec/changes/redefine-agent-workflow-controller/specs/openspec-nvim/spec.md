## MODIFIED Requirements

### Requirement: Neovim-native workspace cockpit

The plugin SHALL provide a Neovim-native workspace cockpit for the selected OpenSpec change that sits between the compact task summary and the full HTML change report.

#### Scenario: Open workspace cockpit

- **WHEN** the user invokes `:OpenSpecWorkspace`
- **THEN** the plugin opens a Neovim workspace surface for the selected change
- **AND** the surface shows change identity, task progress, artifact digest, local health findings, Git context, and recommended upstream action.

#### Scenario: Stay inside Neovim

- **WHEN** the workspace cockpit is opened
- **THEN** the plugin does not open a browser
- **AND** it does not write generated report files into the project tree.

#### Scenario: Preserve existing change selection behavior

- **WHEN** the current buffer is inside an active OpenSpec change
- **THEN** the workspace cockpit uses that change automatically.
- **WHEN** multiple active changes are available and no single current change is inferred
- **THEN** the workspace cockpit asks the user to select one through existing selection flow.

## ADDED Requirements

### Requirement: Upstream OpenSpec workflow boundary

The plugin SHALL treat OpenSpec CLI and generated skills as the owner of propose/apply/verify/sync/archive lifecycle automation.

#### Scenario: Recommend upstream lifecycle action

- **WHEN** a selected change has remaining tasks
- **THEN** the plugin recommends an upstream apply action instead of launching or implementing an agent loop.

#### Scenario: Recommend verification or archive

- **WHEN** a selected change has all tasks complete
- **THEN** the plugin recommends upstream verification and archive actions.

#### Scenario: Avoid duplicate lifecycle commands

- **WHEN** setup registers default commands
- **THEN** the plugin does not register commands that replace upstream propose, apply, verify, sync, or archive workflows.

### Requirement: CLI-backed OpenSpec state

The plugin SHALL prefer structured OpenSpec CLI state when available and degrade to local parsing when unavailable.

#### Scenario: CLI state is available

- **WHEN** `openspec list --json` and `openspec status --change <name> --json` succeed
- **THEN** the workspace uses the CLI-reported progress and artifact readiness.

#### Scenario: CLI is unavailable

- **WHEN** the OpenSpec CLI cannot be executed
- **THEN** the workspace still renders local task and artifact information
- **AND** it reports a non-blocking health finding explaining CLI state is unavailable.

### Requirement: Local health findings

The plugin SHALL report local editor health findings without treating them as workflow gates.

#### Scenario: Report local findings

- **WHEN** the workspace is rendered
- **THEN** findings are grouped by OpenSpec state, artifact state, Git state, and editor selection where applicable.

#### Scenario: Route findings to quickfix

- **WHEN** findings include source artifact paths
- **THEN** the plugin publishes quickfix entries with file/line anchors.

### Requirement: Upstream skill context pack

The plugin SHALL generate a context pack that helps a user invoke upstream OpenSpec skills or commands.

#### Scenario: Build context for upstream action

- **WHEN** the user invokes `:OpenSpecContext`
- **THEN** the generated buffer includes selected change, selected task, artifact excerpts, local findings, validation state, Git state, and suggested upstream action.

#### Scenario: Context does not own task completion

- **WHEN** a context pack is generated
- **THEN** it does not claim `openspec.nvim` owns apply/verify/sync/archive or task-completion automation.

### Requirement: Conservative task mutation

The plugin SHALL keep task mutation explicit and narrow to `tasks.md`.

#### Scenario: Safe local task status update

- **WHEN** `:OpenSpecTaskStatus` executes
- **THEN** it updates only `tasks.md` and does not run upstream lifecycle actions.

### Requirement: Legacy command retirement

The plugin SHALL keep removed gate-like commands unavailable.

#### Scenario: Removed command surface

- **WHEN** setup completes
- **THEN** `OpenSpecAudit` and `OpenSpecPreflight` are not registered.

## REMOVED Requirements

### Requirement: Four-gate workflow lifecycle

**Reason**: Upstream OpenSpec owns lifecycle automation; retaining a separate gate model duplicates workflow state.

**Migration**: Use local health findings and next-action recommendations inside workspace.

### Requirement: Workflow gate finding model

**Reason**: Findings remain useful but are no longer tied to gate state.

**Migration**: Represent findings as local health evidence grouped by source.

### Requirement: Task Binding/Preflight/Context/Handoff/Audit gates

**Reason**: These are now local health and handoff helpers, not lifecycle gates.

**Migration**: Preserve selection and context visibility, remove lifecycle ownership assumptions.
