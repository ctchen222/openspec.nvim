## 1. Spec

- [x] Define Codex goal handoff behavior and compatibility boundaries.
- [x] Capture command, config, prompt, fallback, and edge-case requirements.
- [x] Capture active Codex apply launch behavior instead of passive context-only
  handoff.
- [x] Capture Codex model and effort validation requirements.

## 2. Implementation

- [x] Add `goal` argument parsing and validation for `OpenSpecImplement`.
- [x] Add goal mode resolution through command args, profiles, config defaults,
  and provider defaults.
- [x] Generate an active Codex apply prompt that invokes
  `/opsx:apply <change>` and references the temporary context file.
- [x] Generate a bounded Codex `/goal` objective that references the context
  file, invokes `/opsx:apply <change>`, and includes verification commands.
- [x] Load and parse the Codex model catalog before Codex launches.
- [x] Reject Codex launches with unavailable models or unsupported efforts.
- [x] Render Codex effort through `model_reasoning_effort` configuration instead
  of silently ignoring it.
- [x] Add goal-aware Codex command rendering while preserving existing
  active apply prompt behavior when goal mode is off.
- [x] Add copy fallback behavior for `goal=auto` and `goal=copy`.
- [x] Surface goal mode and objective summary in the launch preview.
- [x] Update README usage and configuration examples.

## 3. Verification

- [x] Cover parser, precedence, Codex command rendering, copy fallback,
  non-Codex rejection, cancellation, long objective, and path escaping tests.
- [x] Cover active apply prompt rendering for goal-off and goal-enabled Codex
  launches.
- [x] Cover invalid Codex model, invalid Codex effort, and unavailable catalog
  fail-closed behavior.
- [x] Cover Codex effort rendering through `model_reasoning_effort`.
- [x] Run `make check`.
- [x] Run `openspec validate --all --strict`.

## 4. Acceptance Criteria

- [x] `:OpenSpecImplement codex` launches with an active prompt that invokes
  `/opsx:apply <change>` and does not wait for another user prompt.
- [x] `:OpenSpecImplement codex goal=auto` launches with a `/goal` objective
  that includes `/opsx:apply <change>`, the temporary context file, and
  verification commands.
- [x] Invalid Codex models, such as unavailable model slugs, fail before any
  provider session or copy-only payload is created.
- [x] Unsupported Codex efforts fail before launch and report supported values.
- [x] Codex `effort` is rendered through `model_reasoning_effort` instead of
  being ignored.
- [x] The change passes `make check` and `openspec validate --all --strict`.
