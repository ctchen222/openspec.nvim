## Context

`OpenSpecImplement` currently resolves an active change, optionally selects a
task from the current `tasks.md` cursor line, evaluates local health, builds a
context file, and launches the configured provider. `health.evaluate()` already
knows when OpenSpec CLI status reports a complete change and can recommend
verify/archive, but `OpenSpecImplement` does not use that state to guard
launches.

## Goals / Non-Goals

**Goals:**

- Prevent accidental implementation launches for completed whole changes.
- Prevent accidental implementation launches for selected `done` or `skipped`
  tasks.
- Keep the warning local to Neovim notifications so the command remains
  lightweight and dependency-free.
- Preserve existing launch behavior for `todo`, `wip`, and whole-change
  requests that still have remaining implementation work.

**Non-Goals:**

- Do not implement archive-buffer handling in this change.
- Do not add a force-launch command or new setup option.
- Do not change provider command templates, goal handoff, or layout resolution.
- Do not make `openspec.nvim` own verify/archive execution.

## Decisions

1. Guard in `M.implement` after health evaluation and before context generation.

   This keeps provider/model/layout resolution untouched and avoids writing a
   temporary context file for launches that should not proceed. It also reuses
   the same state that powers workspace recommendations.

2. Treat selected `done` and `skipped` tasks as completed targets.

   A selected completed task is more specific than whole-change status, so the
   command should stop immediately with a task-level message. This protects the
   focused-task mode where the user may invoke the command from an already
   completed task line.

3. Treat CLI-reported complete changes as completed whole-change targets.

   OpenSpec CLI status is the stronger source of truth for a whole change. If it
   reports complete and no selected incomplete task overrides the scope, the
   command should recommend verify/archive instead of launching implementation.

## Risks / Trade-offs

- [Risk] A user intentionally wants to re-open implementation for a completed
  target. -> Mitigation: this change blocks the accidental default path only;
  a later change can add explicit `force=true` if that workflow becomes common.
- [Risk] CLI status is unavailable or stale. -> Mitigation: guard only on
  selected task status and explicit CLI complete state; unknown state continues
  through the existing launch path.
