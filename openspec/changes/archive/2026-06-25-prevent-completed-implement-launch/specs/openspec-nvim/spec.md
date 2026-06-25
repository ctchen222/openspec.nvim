## ADDED Requirements

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
