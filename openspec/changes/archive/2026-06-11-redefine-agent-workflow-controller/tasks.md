# Plan

- [x] 1. Clarify boundaries and align responsibility
  - [x] 1.1 Remove or update lifecycle ownership wording; demote `Task Binding / Preflight / Context / Audit` to findings or local health.
  - [x] 1.2 Confirm context packs do not claim `openspec.nvim` owns propose/apply/verify/sync/archive.
  - [x] 1.3 Verify `:OpenSpecTaskStatus` only updates `tasks.md`.

- [x] 2. CLI + fallback implementation (if gaps exist)
  - [x] 2.1 Confirm `openspec status --change <name> --json` is integrated into workspace state.
  - [x] 2.2 Confirm `openspec instructions apply --change <name> --json` is used for recommendation context.
  - [x] 2.3 Keep non-blocking fallback and findings behavior stable when no CLI is available.
  - [x] 2.4 Convert `openspec validate --all --strict` output into path-aware findings.

- [x] 3. Workspace cockpit
  - [x] 3.1 Show change identity, task progress, and artifact digest in `:OpenSpecWorkspace`.
  - [x] 3.2 Surface Git branch/worktree/dirty information with path-based findings.
  - [x] 3.3 Limit workspace recommendations to upstream commands/skills only (no execution).
  - [x] 3.4 Support quickfix routing for findings with path/line anchors.

- [x] 4. Context pack
  - [x] 4.1 Add validation state, Git, findings, and suggested upstream action to `:OpenSpecContext`.
  - [x] 4.2 Add explicit wording: "Do not treat this as lifecycle completion" and clear scope boundaries.
  - [x] 4.3 Keep artifact excerpts readable but not as the only source of truth.

- [x] 5. Files and validation
  - [x] 5.1 Complete the change artifact set (proposal/design/tasks/spec) and keep delta headers.
  - [x] 5.2 Update README/developer docs: command surface only, lifecycle owned by OpenSpec upstream.
  - [x] 5.3 Run `make check`.
  - [x] 5.4 Run `openspec validate --all --strict`.
