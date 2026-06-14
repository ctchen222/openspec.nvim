## 1. Implementation

- [x] 1.1 In `context.lua`, make Allowed Scope conditional on `task`: single-task wording when task is non-nil, whole-change wording when task is nil.
- [x] 1.2 In `context.lua`, make Stop Conditions conditional on `task`: include selected-task stop conditions only when task is non-nil.
- [x] 1.3 In `implement.lua` `build_goal_objective`, replace the nil-task fallback text with "No task selected. Implement all tasks in this change in order."
- [x] 1.4 In `implement.lua` `build_apply_prompt`, insert "Implement all tasks in this change in order." at position 3 when task is nil.
- [x] 1.5 In `init.lua`, preserve whole-change mode by passing `nil` through `OpenSpecImplement` when the current cursor does not resolve to a task line in `tasks.md`.
- [x] 1.6 In `health.lua`, allow the implement flow to keep `selected_task = nil` instead of always falling back to `parsed.next_task`.

## 2. Tests

- [x] 2.1 Add `context.lua` tests: Allowed Scope contains "Implement only the selected task" when task is non-nil.
- [x] 2.2 Add `context.lua` tests: Allowed Scope contains "Implement all tasks in this change in order" when task is nil.
- [x] 2.3 Add `context.lua` tests: Stop Conditions include selected-task lines only when task is non-nil.
- [x] 2.4 Add `context.lua` tests: Stop Conditions omit selected-task lines when task is nil.
- [x] 2.5 Add `implement.lua` tests: goal objective includes "all tasks" text when task is nil.
- [x] 2.6 Add `implement.lua` tests: apply prompt includes "all tasks" text when task is nil.
- [x] 2.7 Add `init.lua` tests: `OpenSpecImplement` keeps the selected task on a task line and preserves `nil` off task lines.
- [x] 2.8 Add `health.lua` tests: implement mode can disable fallback to `parsed.next_task` and preserve `selected_task = nil`.
- [x] 2.9 Confirm existing single-task tests still pass without modification.

## 3. Verification

- [x] 3.1 Run `make check`.
- [x] 3.2 Run `openspec validate --all --strict`.
