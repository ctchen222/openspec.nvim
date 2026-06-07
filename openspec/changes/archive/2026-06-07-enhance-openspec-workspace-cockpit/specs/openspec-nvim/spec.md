## MODIFIED Requirements

### Requirement: Neovim-native workspace cockpit
The plugin SHALL provide a Neovim-native workspace cockpit for the selected
OpenSpec change that sits between the compact task summary and the full HTML
change report.

#### Scenario: Open workspace cockpit
- **WHEN** the user invokes `:OpenSpecWorkspace`
- **THEN** the plugin opens a Neovim workspace surface for the selected change
- **AND** the surface shows change identity, task progress, selected task,
  artifact digest, local health findings, Git context, and recommended upstream
  OpenSpec action
- **AND** the surface does not show a second lifecycle state model.

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
can decide which OpenSpec artifact to inspect next without opening the full HTML
report.

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

### Requirement: Local health findings
The plugin SHALL report local editor and repository health findings without
presenting them as a second lifecycle state model.

#### Scenario: Workspace shows local health evidence
- **WHEN** the workspace renders local findings
- **THEN** those findings are grouped as local OpenSpec, artifact, Git, or
  editor evidence
- **AND** they do not approve or block lifecycle execution by themselves.

#### Scenario: Findings route to quickfix when possible
- **WHEN** a finding includes a source path and line number
- **THEN** the plugin can publish that finding as a quickfix entry.
