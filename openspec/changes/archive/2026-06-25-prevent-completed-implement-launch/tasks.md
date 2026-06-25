## 1. Implementation

- [x] 1.1 Add a pre-launch guard for selected `done` and `skipped` tasks.
- [x] 1.2 Add a pre-launch guard for whole-change launches when OpenSpec status
  reports the change as complete.
- [x] 1.3 Keep existing launch behavior for incomplete tasks and incomplete
  whole-change requests.

## 2. Tests

- [x] 2.1 Cover blocked launches for selected `done` and `skipped` tasks.
- [x] 2.2 Cover blocked launches for CLI-complete whole-change requests.
- [x] 2.3 Cover incomplete task and incomplete whole-change launch paths.

## 3. Verification

- [x] 3.1 Run the focused implement tests.
- [x] 3.2 Run the project check suite.
- [x] 3.3 Run strict OpenSpec validation.
