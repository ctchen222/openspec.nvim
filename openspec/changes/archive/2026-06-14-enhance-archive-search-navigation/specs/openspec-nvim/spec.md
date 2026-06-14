## ADDED Requirements

### Requirement: Archive search lifecycle

The plugin SHALL provide deterministic open/close lifecycle behavior for archive views.

#### Scenario: Toggle archive search command

- **WHEN** `:OpenSpecArchiveSearch [query]` is run while archive search is already open
- **AND** the command is issued again
- **THEN** the plugin closes the archive search view
- **AND** does not open a new archive search view.

#### Scenario: Close archive views by command

- **WHEN** archive search (or archive detail) is open
- **AND** the user runs `:OpenSpecArchiveSearch` again
- **THEN** the plugin closes the open archive view(s) so the user can continue from the source buffer.

#### Scenario: Source-window aware artifact shortcuts close archive views on open

- **WHEN** the user is in archive search or archive detail and triggers `p/d/t/s`
- **THEN** the plugin opens the artifact in the recorded source window when possible, otherwise the current window
- **AND** after a successful open, archive search/detail views are closed.
- **WHEN** a spec artifact requires selection
- **THEN** the plugin waits for user selection and closes the views only after the selected target opens successfully.
- **WHEN** the selected artifact is not found
- **THEN** the plugin keeps the archive view open and shows a missing-artifact notification.

### Requirement: Archive search navigation

The plugin SHALL provide read-only archive search navigation for archived OpenSpec changes without mixing archived changes into active change progress.

#### Scenario: Open archive search with buffer-local shortcuts

- **WHEN** the user invokes `:OpenSpecArchiveSearch [query]`
- **THEN** the plugin opens a read-only archive search buffer
- **AND** the buffer provides buffer-local shortcuts for `<Enter>`, `p`, `d`, `t`, `s`, and `q`
- **AND** the shortcuts are not registered as global keymaps.

#### Scenario: Open archive detail from result line

- **WHEN** the cursor is on an archived change result header or source line in the archive search buffer
- **AND** the user presses `<Enter>`
- **THEN** the plugin opens a read-only archive detail buffer for that archived change.

#### Scenario: Open matched artifact from match line

- **WHEN** the cursor is on a matched artifact line in the archive search buffer
- **AND** the user presses `<Enter>`
- **THEN** the plugin opens the matched artifact at the matched line when that line is known.

#### Scenario: Open archived artifacts by shortcut

- **WHEN** the cursor is on a result associated with an archived change
- **AND** the user presses `p`, `d`, `t`, or `s`
- **THEN** the plugin opens that archived change's proposal, design, tasks, or spec artifact respectively.

#### Scenario: Select among multiple archived spec deltas

- **WHEN** an archived change has multiple spec delta artifacts
- **AND** the user presses `s`
- **THEN** the plugin asks the user to select one through `vim.ui.select`.

#### Scenario: Notify missing archived artifact

- **WHEN** the user requests an archived artifact that does not exist
- **THEN** the plugin notifies the user
- **AND** it does not create a new artifact file.

### Requirement: Archive search display

The plugin SHALL render archive search results with concise navigation hints, grouped matches, clear empty states, and bounded output.

#### Scenario: Show archive search key hint

- **WHEN** the archive search buffer is rendered
- **THEN** it shows a concise key hint for `<Enter>`, `p`, `d`, `t`, `s`, and `q`.

#### Scenario: Group query matches by artifact type

- **WHEN** query matches are shown for an archived change
- **THEN** the plugin groups matches by artifact type using Proposal, Design, Tasks, and Spec labels.

#### Scenario: Show match snippets with source locations

- **WHEN** a query match is rendered
- **THEN** the plugin shows the relative artifact path, line number when known, and a concise snippet.

#### Scenario: Highlight query text when possible

- **WHEN** a query is provided
- **AND** matching text appears in rendered snippets
- **THEN** the plugin highlights the query text when Neovim highlighting is available.

#### Scenario: Show no archive state

- **WHEN** no archived changes exist under `openspec/changes/archive`
- **THEN** the plugin shows an empty state that identifies `openspec/changes/archive`.

#### Scenario: Show no match state

- **WHEN** archived changes exist
- **AND** the query has no matches
- **THEN** the plugin tells the user to try a shorter query or run `:OpenSpecArchiveSearch` without a query.

#### Scenario: Cap archive search output

- **WHEN** archive search finds more than the default maximum number of archived changes or snippets
- **THEN** the plugin limits rendered output to 25 archived changes and 5 snippets per archived change
- **AND** it shows a refine-query hint that includes the total result count when known.

### Requirement: Archive detail view

The plugin SHALL provide a read-only archive detail buffer that summarizes an archived change and links back to source artifacts.

#### Scenario: Render archive detail metadata

- **WHEN** an archive detail buffer is opened
- **THEN** it shows the archived change name, source path, archive date when known, task progress, and artifact status.

#### Scenario: Render archive detail excerpts

- **WHEN** archived proposal, design, tasks, or spec artifacts exist
- **THEN** the detail buffer shows concise proposal summary, design excerpts, task checklist excerpt, and spec delta names with excerpts where available.

#### Scenario: Navigate from archive detail

- **WHEN** the archive detail buffer is focused
- **THEN** buffer-local `p`, `d`, `t`, `s`, and `q` shortcuts open proposal, design, tasks, selected spec delta, or close the detail buffer respectively.

#### Scenario: Keep archive detail read-only

- **WHEN** the archive detail buffer is open
- **THEN** the buffer is read-only
- **AND** its filetype is `openspec-archive-detail`.

#### Scenario: Avoid lifecycle execution from archive detail

- **WHEN** the archive detail buffer is open
- **THEN** the plugin does not expose archive, unarchive, apply, verify, sync, or task-completion actions from that buffer.

### Requirement: Summary artifact shortcuts

The plugin SHALL provide buffer-local artifact shortcuts in the compact task summary for the selected active change.

#### Scenario: Show summary artifact key hint

- **WHEN** the task summary buffer is rendered for a selected active change
- **THEN** it shows a concise key hint for `p`, `d`, `t`, and `s` artifact navigation.

#### Scenario: Open active change artifacts by shortcut

- **WHEN** the task summary buffer is focused
- **AND** the user presses `p`, `d`, `t`, or `s`
- **THEN** the plugin opens the selected active change's proposal, design, tasks, or spec artifact respectively.

#### Scenario: Select among multiple active spec deltas

- **WHEN** the selected active change has multiple spec delta artifacts
- **AND** the user presses `s` in the task summary buffer
- **THEN** the plugin asks the user to select one through `vim.ui.select`.

#### Scenario: Notify missing active artifact

- **WHEN** the user requests an active change artifact that does not exist
- **THEN** the plugin notifies the user
- **AND** it does not create a new artifact file.

#### Scenario: Preserve existing summary mapping behavior

- **WHEN** summary artifact shortcuts are installed
- **THEN** the existing configured summary mapping remains unchanged
- **AND** no new default keymaps or setup options are added.

### Requirement: Source-window aware artifact opening

The plugin SHALL open artifacts from summary, archive search, and archive detail buffers in a stable editing window when possible.

#### Scenario: Open artifact in source window

- **WHEN** a summary, archive search, or archive detail buffer was launched from a valid source window
- **AND** the user opens an artifact through a shortcut
- **THEN** the plugin opens the artifact in the source window.

#### Scenario: Fall back to current window

- **WHEN** the recorded source window is no longer valid
- **AND** the user opens an artifact through a shortcut
- **THEN** the plugin opens the artifact in the current window.
