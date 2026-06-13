# Add Codex goal handoff to OpenSpecImplement

## Why

`OpenSpecImplement` can already launch a fresh provider session with a selected
model and a generated implementation context. That gives the new session the
right starting point, but it does not give Codex a persistent definition of done
for longer implementation work.

Codex goal mode is a better fit for implementation handoff because the goal text
can stay attached to the thread while Codex works through multiple steps. The
launcher should make this easier without changing existing `OpenSpecImplement`
behavior or claiming that a goal guarantees successful verification.

## What Changes

- Add an opt-in Codex goal handoff mode to `OpenSpecImplement`.
- Let users request goal handoff from command arguments or implementation
  profiles.
- Generate a short Codex `/goal` objective that points to the temporary
  implementation context file instead of embedding the full context body.
- Preserve the current context-prompt launch path when goal handoff is not
  enabled.
- Provide a copy fallback so users can paste the generated `/goal` command when
  automatic slash-command handoff is not reliable.

## Impact

Users can launch a Codex implementation session with model selection, OpenSpec
context, and an explicit completion target in one workflow. Existing provider
launches remain compatible because goal handoff is opt-in and Codex-specific.

## Non-Goals

- Do not build a generic lifecycle supervisor inside `openspec.nvim`.
- Do not claim that Codex will always complete, verify, or archive the change
  without human review.
- Do not add goal-mode behavior for non-Codex providers until their equivalent
  semantics are known.
- Do not manage worktrees in this change.
