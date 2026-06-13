# Design: Codex goal handoff

## Boundary

Goal handoff is an optional enhancement to `OpenSpecImplement`. This change also
fixes the Codex launch contract so a new Codex session starts the OpenSpec apply
workflow instead of merely reading a context file and waiting for another user
prompt.

`OpenSpecContext` remains a Markdown handoff buffer. `OpenSpecImplement` remains
the launch point for provider, model, layout, and implementation context.

## Command Shape

Extend the existing command with one optional argument:

```vim
:OpenSpecImplement {provider} [profile=<name>] [model=<model>] [effort=<effort>] [layout=<layout>] [goal=<off|auto|copy|true|false>]
```

Goal modes:

- `goal=off` or `goal=false`: launch Codex with an active OpenSpec apply
  instruction, but do not use `/goal`.
- `goal=auto` or `goal=true`: launch Codex with a generated `/goal` objective
  and copy the same objective as a fallback.
- `goal=copy`: launch Codex with the active OpenSpec apply instruction and copy
  the generated `/goal` objective for manual paste.

The default mode is `off` for compatibility.

## Resolution

Resolve goal mode through the same precedence used for model, effort, and
layout:

1. Explicit command argument.
2. Named profile.
3. Config default profile.
4. `implement.goal`.
5. Provider default.

Goal handoff is Codex-specific. If a non-Codex provider is launched with any goal
mode other than `off`, the plugin should report an error before launching.

## Prompt Generation

The default Codex prompt should be active, not advisory. It should instruct Codex
to use `/opsx:apply <change>` for the selected change, read the temporary
implementation context file, treat that file as the source of truth, and begin
implementation without waiting for another user confirmation.

The generated goal objective must be short enough for Codex goal mode and must
point to the temporary context file. It should include:

- OpenSpec change name.
- Selected or next task when available.
- Context file path.
- OpenSpec apply command invocation, `/opsx:apply <change>`.
- Completion criteria.
- Required verification commands: `make check` and
  `openspec validate --all --strict`.
- Stop conditions for missing requirements, unrelated dirty files, scope
  expansion, or failed verification.

The full generated implementation context stays in the temporary context file.
Neither the default apply prompt nor the goal objective should inline the full
Markdown context body.

## Codex Setting Validation

Before launching Codex, validate the resolved model and effort against the Codex
model catalog. Prefer the runtime catalog from `codex debug models`; fall back to
`codex debug models --bundled` only when the runtime catalog cannot be loaded.
If both catalog lookups fail or return unparsable JSON, fail closed before
launching.

Validation rules:

- A resolved Codex model must exist in the catalog.
- A resolved Codex effort must be present in the selected model's
  `supported_reasoning_levels`.
- Invalid model or effort values stop the launch before tmux, Neovim terminal,
  external terminal, or copy-only output is created.
- Error messages should name the rejected value and, when possible, include
  supported alternatives.

Codex does not expose `--effort` as a launch flag. The built-in Codex adapter
should render effort through a config override equivalent to
`model_reasoning_effort = "high"` while continuing to use `--model` for model
selection.

## Command Templates

Keep existing template tokens compatible. Add goal-aware tokens for providers
that opt into them:

- `{initial_prompt}`: active apply prompt when goal is off, goal prompt when goal
  is enabled.
- `{goal_prompt}`: generated `/goal` command text.
- `{goal_feature_flag}`: provider-specific feature flag for goal support when
  needed.

The built-in Codex adapter should use `{initial_prompt}` so goal mode and the
active apply prompt mode share one launch path. Custom Codex templates that do
not include a prompt-capable token such as `{initial_prompt}` or
`{context_prompt}` should fail before launch because they cannot deliver the
OpenSpec apply instruction.

## Copy Fallback

When goal handoff is enabled, the launch preview should show the goal mode and
goal objective summary. For `goal=auto`, the plugin should also copy the full
`/goal` command before launch or during the copy-only launch path. If clipboard
copy fails, the plugin should notify the user.

## Edge Cases

- If Codex does not interpret the initial prompt as a slash command, the copied
  `/goal` command is the supported fallback.
- If the selected Codex model is not in the Codex model catalog, fail before
  launch.
- If the selected effort is not supported by the selected Codex model, fail
  before launch.
- If the Codex model catalog cannot be loaded, fail closed instead of launching
  with unverified settings.
- If `goal=off`, Codex still receives the active OpenSpec apply instruction.
- If the generated goal objective exceeds Codex goal limits, fail before
  launching a provider session.
- If the context path contains spaces, quotes, or shell-sensitive characters,
  the launch command must escape it safely.
- If the launch preview is cancelled, do not launch and do not modify the
  clipboard.
- If no task is selected, generate a change-level goal that tells Codex to use
  the context file to identify the next task.
- If the temporary context file is deleted before Codex reads it, Codex should
  stop and ask for a fresh launch.
