# Add model-enforced OpenSpec implementation launcher

## Why

`OpenSpecContext` can include model routing guidance, but copied Markdown cannot reliably change the model of an already-running Codex, Claude, or other agent session. Model selection is runtime state controlled by the agent process or CLI, so a context block can only remind the user to switch models manually.

Users need a general workflow that preserves the planning/implementation model split without requiring manual session setup. Planning can stay on an expensive high-reasoning model, while implementation can start in a fresh session with the intended implementation model already selected.

## What Changes

- Add an `OpenSpecImplement` launcher workflow that creates implementation context and starts a new agent session with provider/model settings applied at launch.
- Support provider and model selection through command arguments and config-backed profiles.
- Use a preview confirmation step before launching any new session.
- Prefer tmux panes when available; otherwise open a Neovim terminal split, with external terminal launch as an opt-in configuration.
- Keep `OpenSpecContext` model routing guidance, but clearly state that it does not enforce model switching inside existing sessions.

## Impact

- Users can run a single command to start implementation in the intended model instead of copying context and manually switching models.
- `OpenSpecContext` remains useful as shared context and guardrail output, but enforcement belongs to `OpenSpecImplement`.
- Provider support can grow through adapters without hard-coding unverified CLI flags for every agent.
