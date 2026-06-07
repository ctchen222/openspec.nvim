# Proposal: Add Context Model Routing

## Why

`:OpenSpecContext` already creates a focused implementation handoff from the selected OpenSpec task. It does not yet help the user route work across different AI model profiles, so users still have to remember when to use an expensive planning model and when to switch to a cheaper implementation model.

Users should be able to configure model routing once and have every generated context pack carry the same handoff guidance.

## What Changes

- Add configurable model routing guidance to generated context packs.
- Keep routing generic: profiles are labels, model names, reasoning effort, optional activation commands, and usage notes.
- Provide useful default profiles for planning/spec work, implementation, and verification/audit.
- Document how users can customize profile names, model strings, effort labels, commands, and switch rules.

## Non-Goals

- Do not switch models programmatically inside Neovim.
- Do not launch terminal agents or lifecycle automation.
- Do not hard-code OpenAI, Anthropic, or any specific provider as the only supported target.
- Do not change task status or archive/sync behavior.

## Touched Areas

- `lua/openspec/config.lua`
- `lua/openspec/context.lua`
- `tests/context_spec.lua`
- `README.md`
