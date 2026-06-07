# Design

## 1) Clear Division of Responsibilities

```text
User / AI → OpenSpec CLI + generated skills
                          (ownership: propose/apply/verify/sync/archive)
                                   ↑
                                   |
                          status/list/instructions/validation
                                   |
                                   ↓
openspec.nvim (control surface) → discovery / tasks / health / ui / context
                                   |
                         local file updates only: tasks.md checkbox
```

Core principles:

- OpenSpec CLI is the authoritative source; use local parser only when CLI parsing fails.
- The plugin only emits actionable recommendations and does not execute lifecycle actions.
- All findings must be path-resolvable and quickfix-capable when file coordinates are available.

## 2) Data flow

### 2.1 Change discovery

- Discovery traverses upward from the buffer/CWD to `openspec/changes`.
- Current-context cockpit and handoff commands may auto-select the current
  change when the buffer is inside `openspec/changes/<change>/`.
- Summary commands prompt selection via `vim.ui.select`, including the
  single-change case, so the user always confirms which change is being
  summarized.

### 2.2 Parsing and state

- Tasks: parse `tasks.md` first (`checkbox + section + next task`).
- CLI:
  - `openspec status --change <name> --json`
  - `openspec instructions apply --change <name> --json`
  - `openspec validate --all --strict`
- Fallback: emit a non-blocking finding when CLI is unavailable and retain local parse output.

### 2.3 Health layers

- OpenSpec layer: CLI missing, status failed, validation failed.
- Artifact layer: missing/empty proposal/design/task/spec files, missing references.
- Git layer: branch/worktree mismatch, dirty tree.
- Editor layer: invalid selected task/file context.

### 2.4 UI output

- `OpenSpecSummary`: explicit change selection plus compact spec state,
  artifact readiness, task progress, next task, and recommended upstream action.
- `OpenSpecWorkspace`:
  - selected change
  - state/progress summary, artifact digest, sections needing attention
  - findings + quickfix
  - upstream action recommendation (command + skill)
- `OpenSpecContext`:
  - selected task, artifact excerpts, findings, Git, validation
  - explicit scope: not an upstream lifecycle owner

## 3) Implementation boundary (phase mapping)

- Phase 1: redefine boundaries + align docs/command behavior (no new commands).
- Phase 2: CLI adapter + fallback + workspace state integration.
- Phase 3: classify health findings + practical next-action recommendations.
- Phase 4: upstream-safe wording for context pack.
- Phase 5: conservative task mutation + validation/test hardening.

## 4) Validation criteria

- `openspec validate --all --strict` should pass.
- `make test` should pass.
- Workspace should still render without OpenSpec CLI and surface non-blocking findings.
- `:OpenSpecAudit` and `:OpenSpecPreflight` should remain unregistered (already covered by tests).
