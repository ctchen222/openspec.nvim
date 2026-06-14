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
assert(parsed.goal == nil)

local err_args = implement.parse_args({ "codex", "badarg" })
assert(err_args == nil)

local parsed_goal = implement.parse_args({ "codex", "goal=auto" })
assert(parsed_goal.goal == "auto")
local settings_goal_auto = implement.resolve_settings({ provider = "codex", goal = "auto" })
assert(settings_goal_auto.goal == "auto")

local parsed_goal_off = implement.parse_args({ "codex", "goal=false" })
assert(parsed_goal_off.goal == "false")

local settings_goal_false = implement.resolve_settings({ provider = "codex", goal = "false" })
assert(settings_goal_false.goal == "off")

local parsed_goal_copy = implement.parse_args({ "codex", "goal=copy" })
assert(parsed_goal_copy.goal == "copy")

local parsed_goal_true = implement.parse_args({ "codex", "goal=true" })
assert(parsed_goal_true.goal == "true")
local settings_goal_true = implement.resolve_settings({ provider = "codex", goal = "true" })
assert(settings_goal_true.goal == "auto")

local parsed_goal_bad = implement.parse_args({ "codex", "goal=always" })
assert(parsed_goal_bad.goal == "always")
local parsed_goal_bad_settings, parsed_goal_bad_err = implement.resolve_settings(parsed_goal_bad)
assert(parsed_goal_bad_settings == nil)
assert(parsed_goal_bad_err:find("Unsupported goal mode", 1, true))

config.setup({
  implement = {
    default_profile = "default",
    profiles = {
      default = {
        model = "default-model",
        effort = "low",
        layout = "tmux-bottom",
        goal = "copy",
      },
      implementation = {
        model = "impl-model",
        effort = "high",
        layout = "nvim-bottom",
      },
    },
    providers = {
      codex = { model = "provider-model", effort = "provider-effort", model_flag = "--model {model}", effort_flag = "-c model_reasoning_effort={effort}" },
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
assert(settings_fallback.goal == "copy")

local parsed_default_profile = implement.parse_args({ "codex" })
local settings_default_profile = implement.resolve_settings(parsed_default_profile)
assert(settings_default_profile.model == "default-model")
assert(settings_default_profile.effort == "low")
assert(settings_default_profile.layout == "tmux-bottom")
assert(settings_default_profile.goal == "copy")

local codex_context_file = vim.fn.tempname()
vim.fn.writefile({ "codex context line 1", "codex context line 2" }, codex_context_file)
local command, command_err = implement.build_provider_command("codex", { provider = "codex", model = "gpt-test", effort = "high", goal = "off", goal_prompt = nil }, codex_context_file)
assert(command_err == nil)
assert(command:find("codex", 1, true))
assert(command:find("--model", 1, true))
assert(command:find("gpt-test", 1, true))
assert(command:find(codex_context_file, 1, true))
assert(not command:find("codex context line 1", 1, true))
assert(command:find("model_reasoning_effort", 1, true))
assert(not command:find("--effort", 1, true))
assert(command:find("/opsx:apply", 1, true))
assert(command:find("make check", 1, true))
assert(command:find("openspec validate --all --strict", 1, true))

local spaced_context_file = "/tmp/openspec spaced context.md"
local spaced_command, spaced_command_err = implement.build_provider_command("codex", { provider = "codex", model = "gpt-test", effort = "high", goal = "off", goal_prompt = nil }, spaced_context_file)
assert(spaced_command_err == nil)
assert(spaced_command:find("'[^']*" .. spaced_context_file .. "[^']*'", 1) ~= nil)

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

local goal_prompt, goal_summary, goal_err = implement.build_goal_prompt("add-codex-goal-handoff", nil, codex_context_file)
assert(goal_err == nil)
assert(goal_prompt:find("^/goal "))
assert(goal_prompt:find("/opsx:apply add-codex-goal-handoff", 1, true))
assert(goal_summary:find("Completion criteria", 1, true))

-- whole-change mode: goal objective says "all tasks" when task is nil
assert(goal_prompt:find("Implement all tasks in this change in order", 1, true))
assert(not goal_prompt:find("No explicit task selected", 1, true))

-- single-task mode: goal objective mentions selected task when task is non-nil
local task_obj = { section = "1. Implementation", text = "1.1 Do something" }
local goal_task_prompt, _, goal_task_err = implement.build_goal_prompt("add-codex-goal-handoff", task_obj, codex_context_file)
assert(goal_task_err == nil)
assert(goal_task_prompt:find("Selected task", 1, true))
assert(goal_task_prompt:find("1.1 Do something", 1, true))
assert(not goal_task_prompt:find("Implement all tasks in this change in order", 1, true))

-- apply prompt: "all tasks" when task is nil
config.setup({ implement = { providers = { codex = { command_template = "codex {model_flag} {effort_flag} {initial_prompt}", model_flag = "--model {model}", effort_flag = "-c model_reasoning_effort={effort}" } } } })
local all_tasks_cmd, all_tasks_err = implement.build_provider_command("codex", { provider = "codex", model = "gpt-test", effort = "high", goal = "off", task = nil }, codex_context_file)
assert(all_tasks_err == nil)
assert(all_tasks_cmd:find("Implement all tasks in this change in order", 1, true))

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

local valid_catalog = {
  ["gpt-5.5"] = {
    low = true,
    medium = true,
    high = true,
    xhigh = true,
  },
}

local valid_settings = { provider = "codex", model = "gpt-5.5", effort = "high", goal = "off" }
assert(implement.validate_settings(valid_settings, { codex_models = valid_catalog }))

local original_systemlist = vim.fn.systemlist
vim.fn.systemlist = function(_cmd)
  return {
    '{ "models": [ { "slug": "gpt-5.3-codex-spark", "supported_reasoning_levels": [ { "effort": "low" }, { "effort": "medium" }, { "effort": "high" } ] } ] }',
  }
end

local structured_valid, structured_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "high", goal = "off" }, {})
assert(structured_valid, structured_err)

local structured_invalid, structured_invalid_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "ultra", goal = "off" }, {})
assert(structured_invalid == nil)
assert(structured_invalid_err)
assert(not structured_invalid_err:find("table:", 1, true))
assert(structured_invalid_err:find("Available efforts for this model: high, low, medium", 1, true))

local map_catalog = {
  ["gpt-5.3-codex-spark"] = {
    low = { effort = "low" },
    medium = true,
    high = { description = "high effort details" },
    off = false,
  },
}

local map_catalog_valid, map_catalog_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "high", goal = "off" }, { codex_models = map_catalog })
assert(map_catalog_valid, map_catalog_err)
assert(not map_catalog_err)

vim.fn.systemlist = function(_cmd)
  return {
    "WARNING: proceeding, even though we could not create PATH aliases: Operation not permitted (os error 1)",
    '{ "models": [ { "slug": "gpt-5.3-codex-spark", "supported_reasoning_levels": [ { "effort": "low" }, { "effort": "high" } ] } ] }',
  }
end
local warning_valid, warning_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "high", goal = "off" }, {})
assert(warning_valid, warning_err)

vim.fn.systemlist = function(_cmd)
  return {
    "WARNING: command executed from older shell profile",
    '[{ "slug": "gpt-5.3-codex-spark", "base_instructions": "{note: this text contains braces {for testing parser}", "supported_reasoning_levels": [ { "effort": "low" }, { "effort": "medium" }, { "effort": "high" } ] } ]',
  }
end
local nested_blob_valid, nested_blob_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "medium", goal = "off" }, {})
assert(nested_blob_valid, nested_blob_err)
vim.fn.systemlist = original_systemlist

vim.fn.systemlist = function(_cmd)
  return {
    "[{ \"slug\": \"gpt-5.3-codex-spark\", \"supported_levels\": [ { \"level\": \"low\" }, { \"level\": \"medium\" }, { \"level\": \"high\" } ] } ]",
  }
end
local array_catalog_valid, array_catalog_err = implement.validate_settings({ provider = "codex", model = "gpt-5.3-codex-spark", effort = "medium", goal = "off" }, {})
assert(array_catalog_valid, array_catalog_err)
vim.fn.systemlist = original_systemlist

vim.fn.systemlist = original_systemlist

local invalid_model, invalid_model_err = implement.validate_settings({ provider = "codex", model = "bad-model", effort = "high", goal = "off" }, { codex_models = valid_catalog })
assert(invalid_model == nil)
assert(invalid_model_err:find("Codex model not available", 1, true))

local invalid_effort, invalid_effort_err = implement.validate_settings({ provider = "codex", model = "gpt-5.5", effort = "ultra", goal = "off" }, { codex_models = valid_catalog })
assert(invalid_effort == nil)
assert(invalid_effort_err:find("Unsupported Codex effort", 1, true))
assert(invalid_effort_err:find("Available efforts for this model", 1, true))

local non_codex_goal_ok, non_codex_goal_err = implement.validate_settings({ provider = "claude", model = "x", effort = "high", goal = "auto" }, {})
assert(non_codex_goal_ok == nil)
assert(non_codex_goal_err:find("Goal handoff is only supported", 1, true))

config.setup({
  implement = {
    providers = {
      codex = {
        command_template = "codex --model {model} {context_file}",
      },
    },
  },
})
local bad_template, bad_template_err = implement.build_provider_command("codex", { provider = "codex", model = "gpt-test", effort = "high", goal = "off" }, codex_context_file)
assert(bad_template == nil)
assert(bad_template_err:find("must include {initial_prompt}", 1, true))

config.setup({
  implement = {
    providers = {
      codex = {
        command_template = "codex {model_flag} {effort_flag} {initial_prompt}",
        model_flag = "--model {model}",
        effort_flag = "-c model_reasoning_effort={effort}",
      },
    },
  },
})
local bad_goal_template, bad_goal_template_err = implement.build_provider_command("codex", { provider = "codex", model = "gpt-test", effort = "high", goal = "auto" }, codex_context_file)
assert(bad_goal_template == nil)
assert(bad_goal_template_err:find("Goal mode auto requires", 1, true))

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

local preview = implement.preview_text({
  provider = "codex",
  model = "gpt-test",
  effort = "high",
  layout = "tmux-right",
  change_name = "test-change",
  goal_mode = "auto",
  goal_summary = "Use this command and verify before completion.",
  task = { section = "spec", text = "implement this" },
  context_file = "/tmp/context.md",
  command = "codex --model x --goal y",
})
assert(preview:find("Goal mode: auto", 1, true))
assert(preview:find("Goal objective: Use this command and verify before completion.", 1, true))

local long_goal = string.rep("a", 5000)
local long_goal_prompt, _, long_goal_err = implement.build_goal_prompt("change", { section = "x", text = long_goal }, "/tmp/context.md")
assert(long_goal_prompt == nil)
assert(long_goal_err:find("exceeds Codex goal limit", 1, true))

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
