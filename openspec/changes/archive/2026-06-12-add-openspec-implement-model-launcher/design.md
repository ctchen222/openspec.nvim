# Design: OpenSpecImplement model launcher

## Boundary

`OpenSpecContext` generates text. It may include model recommendations, launch commands, and warnings, but it must not imply that pasted context can force an existing agent session to switch models.

`OpenSpecImplement` owns enforcement. It launches a new provider process and applies the selected model through provider-specific CLI arguments or configured adapter templates.

## Command Shape

Primary command:

```vim
:OpenSpecImplement {provider} [profile=<name>] [model=<model>] [effort=<effort>] [layout=<auto|tmux-right|tmux-bottom|nvim-right|nvim-bottom|external|copy>]
```

Examples:

```vim
:OpenSpecImplement codex profile=implementation
:OpenSpecImplement codex model=gpt-5.4 effort=high
:OpenSpecImplement claude model=sonnet effort=high
```

Resolution order:

1. Explicit command arguments.
2. Named profile such as `implementation`.
3. Config default profile.
4. Provider adapter default.

## Provider Adapters

Built-in adapters:

- `codex`: launches an interactive Codex session and applies the selected model through Codex CLI model options.
- `claude`: launches an interactive Claude session and applies selected model/effort through Claude CLI options.

Configurable adapters:

- `opencode`: supported through a user-configured command template until its CLI model flags are verified.
- Future providers can be added without changing the command UX.

## Launch Flow

1. Generate implementation context from the same source used by `OpenSpecContext`.
2. Write the full context to a temporary file to avoid shell argument length limits.
3. Show a Neovim preview confirmation with provider, model, effort, layout, target change/task, temp file path, and command summary.
4. If the user cancels, do not launch any provider command.
5. If confirmed, launch a new interactive session.

Display rules:

- If tmux is available and `layout=auto`, open a right pane when the current pane is wide enough; otherwise fall back to a bottom pane.
- If tmux is unavailable and `layout=auto`, open a Neovim right terminal split by default.
- Users can configure Neovim bottom split, Neovim right split, external terminal, or copy-only launch output.

## Non-Goals

- Do not mutate or control the model of an already-running Codex or Claude conversation.
- Do not build a custom chat UI inside openspec.nvim.
- Do not claim first-class `opencode` flag support before its CLI behavior is verified.
