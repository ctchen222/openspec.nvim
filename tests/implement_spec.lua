dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({
  commands = false,
  keymaps = false,
})

local config = require("openspec.config")
local implement = require("openspec.implement")

local parsed = implement.parse_args({ "codex", "profile=implementation", "model=gpt-5.4", "effort=high", "layout=tmux-right" })
assert(parsed.provider == "codex")
assert(parsed.profile == "implementation")
assert(parsed.model == "gpt-5.4")
assert(parsed.effort == "high")
assert(parsed.layout == "tmux-right")

local err_args = implement.parse_args({ "codex", "badarg" })
assert(err_args == nil)

config.setup({
  implement = {
    default_profile = "default",
    profiles = {
      default = { model = "default-model", effort = "low", layout = "tmux-bottom" },
      implementation = { model = "impl-model", effort = "high", layout = "nvim-bottom" },
    },
    providers = {
      codex = { model = "provider-model", effort = "provider-effort", model_flag = "--model {model}", effort_flag = "--effort {effort}" },
    },
  },
})

local parsed_precedence = implement.parse_args({ "codex", "profile=implementation", "model=explicit-model", "effort=explicit-effort" })
local settings_precedence = implement.resolve_settings(parsed_precedence)
assert(settings_precedence.model == "explicit-model")
assert(settings_precedence.effort == "explicit-effort")
assert(settings_precedence.layout == "nvim-bottom")

local parsed_fallback = implement.parse_args({ "codex", "profile=implementation" })
local settings_fallback = implement.resolve_settings(parsed_fallback)
assert(settings_fallback.model == "impl-model")
assert(settings_fallback.effort == "high")
assert(settings_fallback.layout == "nvim-bottom")

local parsed_default_profile = implement.parse_args({ "codex" })
local settings_default_profile = implement.resolve_settings(parsed_default_profile)
assert(settings_default_profile.model == "default-model")
assert(settings_default_profile.effort == "low")
assert(settings_default_profile.layout == "tmux-bottom")

local codex_context_file = vim.fn.tempname()
vim.fn.writefile({ "codex context line 1", "codex context line 2" }, codex_context_file)
local command, command_err = implement.build_provider_command("codex", { model = "gpt-test", effort = "high" }, codex_context_file)
assert(command_err == nil)
assert(command:find("codex", 1, true))
assert(command:find("--model", 1, true))
assert(command:find("gpt-test", 1, true))
assert(command:find(codex_context_file, 1, true))
assert(not command:find("codex context line 1", 1, true))
assert(not command:find("--effort", 1, true))

local claude_command, claude_command_err = implement.build_provider_command("claude", { model = "sonnet-test", effort = "max" }, codex_context_file)
assert(claude_command_err == nil)
assert(claude_command:find("claude", 1, true))
assert(claude_command:find("--model", 1, true))
assert(claude_command:find("sonnet-test", 1, true))
assert(claude_command:find("--effort", 1, true))
assert(claude_command:find("max", 1, true))
assert(claude_command:find(codex_context_file, 1, true))
assert(not claude_command:find("codex context line 1", 1, true))
assert(not claude_command:find("|", 1, true))
assert(not claude_command:find("cat ", 1, true))

config.setup({
  implement = {
    providers = {
      opencode = {
        command_template = "opencode --context {context_file} --model {model} --effort {effort}",
      },
    },
  },
})

local opencode_context_file = vim.fn.tempname()
vim.fn.writefile({ "opencode context line 1", "opencode context line 2" }, opencode_context_file)
local command_template, command_template_err = implement.build_provider_command("opencode", { model = "opal-model", effort = "low" }, opencode_context_file)
assert(command_template_err == nil)
assert(command_template:find("opencode", 1, true))
assert(command_template:find("opal-model", 1, true))
assert(command_template:find(opencode_context_file, 1, true))

local wide = implement.resolve_layout("auto", { available = true, pane_width = 220 }, {})
assert(wide == "tmux-right")

local narrow = implement.resolve_layout("auto", { available = true, pane_width = 90 }, {})
assert(narrow == "tmux-bottom")

local non_tmux = implement.resolve_layout("auto", { available = false, pane_width = 0 }, {})
assert(non_tmux == "nvim-right")

assert(implement._tmux_pane_title({ change_name = "add-openspec-implement-model-launcher" }) == "spec: add-openspec-implement-model-launcher")
assert(implement._tmux_pane_title({ change_name = " spec\nline  with   spaces " }) == "spec: spec line with spaces")
assert(implement._tmux_pane_title({ provider = "codex", model = "gpt-5.4" }) == "codex / gpt-5.4")
assert(implement._tmux_pane_title({}) == "provider")

local cancel_plan = {
  provider = "codex",
  model = "gpt-test",
  effort = "high",
  layout = "copy",
  task = nil,
  change_name = "test-change",
  context_file = "/tmp/ctx.md",
  command = "echo test",
}

local launched = false
local result_cancelled = implement.launch_plan(cancel_plan, {
  confirm = function() return false end,
  execute = function() launched = true end,
})
assert(result_cancelled.launched == false)
assert(launched == false)

local result_confirmed = implement.launch_plan(cancel_plan, {
  confirm = function() return true end,
  execute = function() launched = true; return true end,
})
assert(result_confirmed.launched == true)
assert(launched == true)

print("implement ok")
