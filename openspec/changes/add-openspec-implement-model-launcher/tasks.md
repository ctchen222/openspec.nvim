## 1. Spec and Context Semantics

- [x] Update `OpenSpecContext` copy so model routing is framed as guidance, not enforcement.
- [x] Add launch-command guidance that points users to `OpenSpecImplement` when they need guaranteed model selection.

## 2. Command and Config

- [x] Add `:OpenSpecImplement {provider}` command parsing for `profile`, `model`, `effort`, and `layout`.
- [x] Add config for model profiles, provider defaults, and configurable provider command templates.
- [x] Implement resolution precedence: command args, profile, default profile, provider default.

## 3. Provider Launching

- [x] Add built-in Codex adapter for interactive implementation sessions with model selection.
- [x] Add built-in Claude adapter for interactive implementation sessions with model/effort selection.
- [x] Add configurable adapter support for opencode and future providers.
- [x] Write generated context to a temp file and pass it through provider-safe launch behavior.

## 4. Display Surfaces

- [x] Add preview confirmation before launching any session.
- [x] Add tmux auto layout: right pane when wide enough, bottom pane fallback when narrow.
- [x] Add non-tmux fallback: Neovim right terminal split by default.
- [x] Add configurable layouts for Neovim bottom split, external terminal, and copy-only output.

## 5. Tests

- [x] Cover command argument parsing and precedence.
- [x] Cover adapter command rendering and temp context file handoff.
- [x] Cover preview cancel versus confirm behavior.
- [x] Cover tmux auto layout decision and non-tmux Neovim fallback.
- [x] Cover `OpenSpecContext` wording so it does not claim existing sessions auto-switch models.
