dofile("tests/minimal_init.lua")

-- Characterization tests for OpenSpecImplement edge cases.
-- These lock in the CURRENT (shipped-default) behavior so the footguns below
-- are visible and covered. They are NOT an endorsement that the behavior is
-- ideal; see the inline notes. If the behavior is intentionally changed, update
-- these assertions together with tests/implement_spec.lua.

local openspec = require("openspec")
openspec.setup({
  commands = false,
  keymaps = false,
})

local config = require("openspec.config")
local implement = require("openspec.implement")

local ctx_file = vim.fn.tempname() .. ".md"
vim.fn.writefile({ "context line 1", "context line 2" }, ctx_file)

--------------------------------------------------------------------------------
-- Edge case A: provider/profile model "bleed", now guarded by validation.
--
-- The shipped default config defines `default_profile = "implementation"` whose
-- model is the codex-specific "gpt-5.4". Because resolve_settings precedence is
--   explicit arg > requested profile > DEFAULT PROFILE > provider builtin,
-- running `:OpenSpecImplement claude` with NO model still RESOLVES to "gpt-5.4".
-- That bleed is intended precedence, so it is left intact at the settings layer
-- -- but validate_settings now rejects a non-claude model before launch.
--------------------------------------------------------------------------------

-- The bleed still happens at the settings layer (intended precedence).
local claude_default = implement.resolve_settings({ provider = "claude" })
assert(claude_default ~= nil)
assert(claude_default.model == "gpt-5.4", "expected default-profile model to bleed into claude, got " .. tostring(claude_default.model))

-- But validation now catches the codex model before it can launch claude.
local guarded, guarded_err = implement.validate_settings(
  { provider = "claude", model = claude_default.model, effort = claude_default.effort, goal = "off" },
  {}
)
assert(guarded == nil)
assert(guarded_err:find("Claude model not recognized", 1, true))

-- Correct usage: pass model=opus explicitly. It overrides the bleed and validates.
local claude_opus = implement.resolve_settings({ provider = "claude", model = "opus" })
assert(claude_opus.model == "opus")
assert(implement.validate_settings(
  { provider = "claude", model = claude_opus.model, effort = claude_opus.effort, goal = "off" },
  {}
))
local opus_cmd = implement.build_provider_command(
  "claude",
  { provider = "claude", model = claude_opus.model, effort = claude_opus.effort },
  ctx_file
)
assert(opus_cmd:find("claude", 1, true))
assert(opus_cmd:find("--model", 1, true))
assert(opus_cmd:find("opus", 1, true))
assert(not opus_cmd:find("gpt-5.4", 1, true))

-- Full claude model ids also validate.
assert(implement.validate_settings({ provider = "claude", model = "claude-opus-4-8", effort = "high", goal = "off" }, {}))

--------------------------------------------------------------------------------
-- Edge case B: claude built-in adapter no longer renders `--effort`.
--
-- The upstream `claude` CLI has no `--effort` flag, so the builtin drops it. A
-- default claude launch is `claude --model <model> <context_prompt>`.
--------------------------------------------------------------------------------

local effort_cmd = implement.build_provider_command(
  "claude",
  { provider = "claude", model = "opus", effort = "high" },
  ctx_file
)
assert(effort_cmd:find("--model", 1, true))
assert(effort_cmd:find("opus", 1, true))
assert(not effort_cmd:find("--effort", 1, true), "claude builtin still injects --effort: " .. effort_cmd)

-- Opt-in: a custom claude wrapper that accepts an effort flag can restore it via
-- config by overriding both the command_template (to add the {effort_flag} slot)
-- and the effort_flag itself.
config.setup({
  commands = false,
  keymaps = false,
  implement = {
    providers = {
      claude = {
        command_template = "claude {model_flag} {effort_flag} {context_prompt}",
        effort_flag = "--effort {effort}",
      },
    },
  },
})
local custom_effort_cmd = implement.build_provider_command(
  "claude",
  { provider = "claude", model = "opus", effort = "high" },
  ctx_file
)
assert(custom_effort_cmd:find("--effort", 1, true), "custom effort_flag did not render: " .. custom_effort_cmd)
assert(custom_effort_cmd:find("high", 1, true))

-- Restore default config for the layout assertions below.
config.setup({ commands = false, keymaps = false })

--------------------------------------------------------------------------------
-- Edge case C (your Q3): explicit layout=tmux-right bypasses the pane-width
-- threshold entirely. resolve_layout returns non-"auto" requests verbatim, so
-- even on a very narrow pane it will NOT fall back to tmux-bottom.
--------------------------------------------------------------------------------

-- Explicit tmux-right is returned as-is regardless of pane width (no fallback).
local explicit_narrow = implement.resolve_layout("tmux-right", { available = true, pane_width = 40 }, {})
assert(explicit_narrow == "tmux-right", "explicit tmux-right should not be downgraded on narrow pane")

local explicit_no_tmux = implement.resolve_layout("tmux-right", { available = false, pane_width = 0 }, {})
assert(explicit_no_tmux == "tmux-right", "explicit tmux-right is not rewritten even without tmux context")

-- Contrast: only layout=auto consults min_pane_width_for_right (default 140).
local auto_narrow = implement.resolve_layout("auto", { available = true, pane_width = 40 }, {})
assert(auto_narrow == "tmux-bottom", "auto on narrow pane should downgrade to tmux-bottom")

local auto_wide = implement.resolve_layout("auto", { available = true, pane_width = 200 }, {})
assert(auto_wide == "tmux-right")

print("implement edge cases ok")
