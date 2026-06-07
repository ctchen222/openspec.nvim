# Roadmap: OpenSpec SDD control surface for Neovim

## Product thesis

As AI writes more code, the hard part shifts from code generation to keeping
intent, specs, tasks, code changes, and validation aligned.

`openspec.nvim` should become the Neovim control surface for OpenSpec
spec-driven development. It should show the current OpenSpec state, make the
next action obvious, assemble high-quality AI context, and keep validation close
to the editing loop while OpenSpec markdown stays the source of truth.

The v1 task dashboard is the first slice of that control surface. It answers
"what is left?" for one active change. The roadmap expands that into "where am I
in the OpenSpec workflow, what should I do next, and what context should AI see
before it changes code?"

## User job

When a developer is working in Neovim on an OpenSpec change, they need to answer
these questions quickly:

- Which OpenSpec change am I working on?
- What is the current proposal, design, task, and spec delta?
- What is complete, in progress, blocked, skipped, or not started?
- What is the next action that moves this change forward?
- Did the AI-generated code stay aligned with the OpenSpec artifacts?
- What validation should run before I trust the result?
- What context should be handed to an AI assistant before it edits code?

## Current implementation snapshot

The current implementation is a read-only OpenSpec task-tracking layer:

- Discovers the nearest `openspec/changes` directory from the current buffer or
  working directory.
- Selects the current change from `openspec/changes/<change>/` when possible.
- Falls back to `vim.ui.select` when multiple active changes have `tasks.md`.
- Parses default and configured `tasks.md` checkbox states.
- Shows a toggleable floating summary with progress, section counts, and next
  todo or WIP task.
- Sends remaining tasks or all tasks to quickfix.
- Jumps to the next todo or WIP task.
- Opens a temporary HTML dashboard without writing generated files into the
  project tree.
- Exposes `require("openspec").setup(opts)` and the current command set:
  `:OpenSpecTasksSummary`, `:OpenSpecTasks`, `:OpenSpecTasksAll`,
  `:OpenSpecTasksNext`, and `:OpenSpecTasksHtml`.

This is useful, but it is not yet a full SDD control surface. It only sees
`tasks.md`; it does not understand proposal/design/spec relationships, OpenSpec
CLI validation, AI context, branch state, git diff alignment, or archive history.

## Gap review

| Area | Current state | Roadmap gap |
| --- | --- | --- |
| Active change awareness | Reads one selected change with `tasks.md` | Project-wide overview of all active changes |
| Artifact model | Parses `tasks.md` only | Link proposal, design, task, and spec delta artifacts |
| Validation | No OpenSpec CLI integration in the plugin | Run validation and surface errors in Neovim |
| AI collaboration | No assistant-facing context output | Build a context pack from OpenSpec artifacts and current task |
| Code alignment | No git diff or branch awareness | Show whether code changes map back to tasks/specs |
| Workflow actions | Read-only by design | Add explicit, opt-in task state changes after read-only flow is stable |
| Navigation | Quickfix and next-task jump | Workspace view, artifact navigation, Telescope, and Trouble adapters |
| Reporting | Temporary HTML task dashboard | Shareable status reports and richer HTML filtering |
| History | Ignores archive by default | Browse archived changes without mixing them into active progress |

## Phase 0: Finish and harden the extraction

Goal: make the current read-only plugin slice reliable enough to build on.

Scope:

- Finish the remaining verification tasks in this change.
- Verify the standalone headless test suite.
- Verify the personal Neovim config loads the plugin instead of the old local
  module.
- Run strict OpenSpec validation.
- Keep the setup API, command names, and keymaps documented.

Definition of done:

- `make check` passes.
- The personal Neovim config can use this repository as the plugin source.
- The current extraction change can be archived without losing known roadmap
  decisions.

## Phase 1: Situational awareness workspace

Goal: make Neovim answer "where am I in SDD?" in one or two commands.

Candidate commands:

- `:OpenSpecOverview` shows all active changes, progress, next task, and stale or
  blocked signals.
- `:OpenSpecWorkspace` shows the current change with proposal, design, tasks,
  spec deltas, next action, and validation status.
- `:OpenSpecCurrent` explains how the plugin chose the current change.

Scope:

- Reuse the existing discovery and task parser.
- Add project-wide active change aggregation.
- Add branch-to-change inference for common branch names.
- Keep UI dependency-free by default.

Definition of done:

- A developer can open Neovim in an OpenSpec repo and identify the active change,
  next action, and overall project status without leaving the editor.

## Phase 2: Artifact navigation and validation loop

Goal: connect task progress to the rest of the OpenSpec system.

Candidate commands:

- `:OpenSpecArtifacts` opens proposal, design, tasks, and spec deltas for the
  selected change.
- `:OpenSpecValidate` runs strict validation and sends findings to quickfix.
- `:OpenSpecValidateCurrent` validates the current change when the CLI supports a
  focused target, otherwise validates all and filters the view.

Scope:

- Parse `openspec/config.yaml` before assuming artifact names forever.
- Add navigation entries for `proposal.md`, `design.md`, `tasks.md`, and
  `specs/*/spec.md`.
- Wrap OpenSpec CLI validation as an optional integration.
- Surface validation output in quickfix or a focused floating report.

Definition of done:

- A developer can move from a task to the relevant design/spec artifact and run
  validation from Neovim before asking AI to continue.

## Phase 3: AI collaboration context pack

Goal: make AI-assisted coding start from the right OpenSpec context.

Candidate commands:

- `:OpenSpecContext` builds a context pack from proposal, design, tasks, current
  task, relevant spec deltas, validation status, and git diff summary.
- `:OpenSpecPrompt` copies or opens a prompt-ready summary for the user's chosen
  assistant.
- `:OpenSpecImpact` shows which specs and source areas appear connected to the
  current task.

Scope:

- Keep assistant integration adapter-based. Do not hardcode one AI tool.
- Do not make generated content the source of truth.
- Prefer explicit user actions for copying, opening, or sending context.
- Redact or avoid secrets by default.

Definition of done:

- Before an AI assistant edits code, the developer can hand it a compact,
  artifact-grounded context pack that states the current task, constraints,
  acceptance criteria, validation status, and known risks.

## Phase 4: Guided execution and safe mutation

Goal: close the loop between OpenSpec tasks, implementation progress, and local
code changes.

Candidate commands:

- `:OpenSpecTaskStart` marks a selected todo task as WIP after confirmation.
- `:OpenSpecTaskDone` marks a selected task done after confirmation.
- `:OpenSpecDiff` summarizes changed files and asks which OpenSpec task or spec
  they relate to.
- `:OpenSpecAudit` flags code changes without obvious OpenSpec task coverage.

Scope:

- Keep mutation opt-in and reversible through normal git diff.
- Preserve markdown artifacts as editable files.
- Require confirmation before changing task state.
- Use existing quickfix/workspace selections before adding complex UI.

Definition of done:

- The developer can update task state from Neovim and detect when implementation
  work has drifted away from the OpenSpec plan.

## Phase 5: Integrations, reporting, and archive awareness

Goal: make the control surface pleasant for daily use without making optional UI
plugins mandatory.

Scope:

- Telescope picker for changes, tasks, and artifacts.
- Trouble adapter for task and validation findings.
- Richer HTML reports with filters, section progress, and print-friendly output.
- Markdown status report export for PR descriptions or standups.
- Archive browser for completed changes, clearly separated from active progress.

Definition of done:

- Users with optional UI plugins get richer navigation, while minimal Neovim users
  still have quickfix and floating-window fallbacks.

## Non-goals

- Do not become a general Markdown preview plugin.
- Do not replace the OpenSpec CLI.
- Do not become an autonomous coding agent.
- Do not require Telescope, Trouble, or any AI assistant.
- Do not mutate OpenSpec artifacts by default.
- Do not treat AI-generated summaries as canonical project state.

## Success signals

- Current OpenSpec state is visible from Neovim in under five seconds.
- The next OpenSpec action is available without manually opening several files.
- Validation errors appear where a Neovim user already acts, such as quickfix or a
  focused report.
- AI context packs reduce missing-requirement edits and stale implementation
  attempts.
- Reviewers can trace code changes back to tasks and spec deltas.
- The project stays small, optional, and source-of-truth preserving.

## Suggested next OpenSpec changes

After this extraction change is complete, split future work into separate,
reviewable changes:

1. `add-openspec-overview-workspace`
   - Build `:OpenSpecOverview`, `:OpenSpecWorkspace`, and branch-to-change
     inference.
2. `add-openspec-artifact-validation`
   - Add artifact navigation and OpenSpec CLI validation output.
3. `add-openspec-ai-context-pack`
   - Generate assistant-ready context from OpenSpec artifacts, current task,
     validation state, and git diff summary.
4. `add-openspec-guided-task-mutation`
   - Add confirmed task status updates and diff-to-task audit.
5. `add-openspec-integrations-reporting`
   - Add optional Telescope/Trouble adapters, richer HTML reports, markdown
     exports, and archive browsing.
