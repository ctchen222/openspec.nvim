# Design: Full-change implementation mode

## Boundary

This change modifies context and prompt text generation plus the
`OpenSpecImplement`/health plumbing required to preserve a nil task selection.
It does not touch layout resolution, model validation, the summary buffer UI,
or add a new task-selection primitive. The distinction between modes is
entirely driven by whether `state.selected_task` (and the `task` parameter
passed through the call chain) is nil or non-nil.

## Mode Detection

The mode is determined implicitly by whether the current invocation resolves a
task:

- cursor on a task line in `tasks.md` → single-task mode: scope the agent to
  the selected task.
- any invocation that does not resolve a task line in `tasks.md` →
  whole-change mode: instruct the agent to implement all tasks.

No new parameter, flag, or config key is introduced. The caller already passes
`task` from `state.selected_task`; this change makes nil a meaningful mode
rather than a fallback with a confusing message. The launch path also needs to
preserve nil instead of silently replacing it with `parsed.next_task`.

## Changes to `context.lua`

### Allowed Scope section

**Single-task mode (task non-nil)** — unchanged:
```
- Implement only the selected task.
- Update OpenSpec artifacts only when implementation proves the task/spec is stale or incomplete.
- Touch code, tests, and docs that directly support the selected task.
```

**Whole-change mode (task nil)**:
```
- Implement all tasks in this change in order.
- Update OpenSpec artifacts only when implementation proves a task or spec is stale or incomplete.
- Touch code, tests, and docs that directly support each task.
```

### Stop Conditions section

**Single-task mode (task non-nil)** — unchanged:
```
- Stop if implementation requires expanding the selected task scope.
- Stop if a referenced file is missing and the correct replacement is unclear.
- Stop if local changes cannot be mapped back to the selected task.
- Stop if validation or project checks fail after a focused fix attempt.
```

**Whole-change mode (task nil)**:
```
- Stop if a referenced file is missing and the correct replacement is unclear.
- Stop if validation or project checks fail after a focused fix attempt.
- Stop and request human input if scope needs expansion beyond the tasks listed in this change.
```

The two stop conditions that reference "the selected task" are omitted in
whole-change mode because they would incorrectly block the agent from moving
between tasks.

## Changes to `implement.lua`

### `build_goal_objective`

The `else` branch (task nil) currently reads:
> "No explicit task selected. Use the context file to identify the next task."

Replace with:
> "No task selected. Implement all tasks in this change in order."

This makes the `/goal` handoff objective consistent with the context scope.

### `build_apply_prompt`

When `task` is nil, `task_label` is empty and nothing is inserted. Add an
explicit instruction in the nil case:
> "Implement all tasks in this change in order."

inserted at position 3 (same slot as the task label), so the prompt reads
coherently as: "Use /opsx:apply … for …. Implement all tasks in this change in
order. Read and use the implementation context in …"

## Changes to `init.lua`

`OpenSpecImplement` currently computes `lnum` only when the current buffer is
`tasks.md`, but then calls `select_task(parsed, lnum)`. Because `select_task`
falls back to `parsed.next_task` when `lnum` is nil, invoking the command
outside `tasks.md` still behaves like single-task mode.

Update `OpenSpecImplement` so that it:

- resolves a selected task only when the current buffer is `tasks.md`, and
- preserves `selected_task = nil` for all other invocations or non-task lines.

This keeps existing task-line behavior intact while enabling whole-change mode
without new command arguments.

## Changes to `health.lua`

`health.evaluate` currently sets:

```lua
local selected_task = parsed and (opts.task or parsed.next_task)
```

That fallback is correct for workspace/current surfaces, but it prevents
`OpenSpecImplement` from preserving whole-change mode once `task` is nil.

Add an explicit opt-out so the implement flow can disable the fallback and keep
`selected_task = nil` all the way through context generation.

## Edge Cases

- If `task` is nil but the tasks file is empty or missing, the whole-change
  instruction is still generated. The agent will discover the empty task list
  from the context file and should stop with a finding rather than fabricating
  tasks.
- If `task` is non-nil but its text is empty, single-task mode applies. The
  existing behavior handles this case.
- If `OpenSpecImplement` is invoked outside `tasks.md`, whole-change mode
  applies because no task line can be resolved from the current cursor.
- No changes are needed to verification commands; both modes use the same
  `make check` and `openspec validate --all --strict` block.
