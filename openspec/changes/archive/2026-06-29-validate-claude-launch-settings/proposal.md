## Why

The `claude` provider adapter has two launch footguns that only surface at
runtime:

1. The shipped default profile (`implementation`) carries the codex-specific
   model `gpt-5.4`. Because default-profile values outrank provider defaults,
   running `:OpenSpecImplement claude` with no `model=` resolves to `gpt-5.4`.
   Unlike Codex, Claude had no launch-time model validation, so the bad model
   reached the `claude` CLI silently.
2. The builtin Claude command template injected `--effort`, a flag the upstream
   `claude` CLI does not accept, so a default launch could fail in the CLI.

## What Changes

- Validate the resolved Claude model before launch. Accept Claude CLI aliases
  (`opus`, `sonnet`, `haiku`, `default`, `opusplan`) and full Anthropic model
  ids (`claude-*`, or ids containing a known family name). Reject anything else
  before any provider session starts, with guidance to pass `model=opus`.
- Stop injecting `--effort` in the builtin Claude command template. The Claude
  adapter renders `claude {model_flag} {context_prompt}` by default. A custom
  wrapper that accepts an effort flag can restore it via provider config.
- Keep the `effort` value resolvable for the launch preview and profiles.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-nvim`: `OpenSpecImplement` now validates Claude launch settings and
  renders the Claude command without a `--effort` flag by default.

## Impact

- Affects `:OpenSpecImplement claude` launch behavior.
- Affects `lua/openspec/implement.lua` and focused implement tests.
- Does not change Codex behavior, public setup options, or default keymaps.
- Provider adapter configuration remains backward compatible: a custom
  `command_template`/`effort_flag` still wins over the builtin default.
