local config = require("openspec.config")
local util = require("openspec.util")

local M = {}

local BUILTIN_ADAPTERS = {
  codex = {
    command_template = "codex {model_flag} {context_prompt}",
    model_flag = "--model {model}",
    model = "gpt-5.4",
    effort = "high",
    layout = "auto",
  },
  claude = {
    command_template = "claude {model_flag} {effort_flag} {context_prompt}",
    model_flag = "--model {model}",
    effort_flag = "--effort {effort}",
    model = "sonnet",
    effort = "high",
    layout = "auto",
  },
}

local LOG_PATH = (vim.env.TMPDIR or "/tmp") .. "/openspec-implement.log"

local function append_log(message)
  local ts = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local line = string.format("[%s] %s", ts, message)
  local ok, err = pcall(vim.fn.writefile, { line }, LOG_PATH, "a")
  if not ok then
    util.notify("Failed to write implement log: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function trim(value)
  return (value:gsub("^%s+", "")):gsub("%s+$", "")
end

local function normalize_space(value)
  value = value:gsub("\n", " ")
  value = value:gsub("%s+", " ")
  return trim(value)
end

local function to_pane_title(value)
  if not value then
    return ""
  end
  value = value:gsub("[\r\n]", " ")
  value = value:gsub("%s+", " ")
  value = trim(value)
  value = value:sub(1, 60)
  return value
end

function M._merge_provider(provider)
  local configured = config.get().implement and config.get().implement.providers or {}
  local base = vim.tbl_deep_extend("force", vim.deepcopy(BUILTIN_ADAPTERS[provider] or {}), configured[provider] or {})
  return base
end

local function parse_key_value(raw)
  local key, value = raw:match("^([%w_%-]+)%=(.*)$")
  if not key then
    return nil
  end
  return key, value
end

function M.parse_args(fargs)
  if not fargs or #fargs == 0 then
    return nil, "Usage: :OpenSpecImplement {provider} [profile=<name>] [model=<model>] [effort=<effort>] [layout=<layout>]"
  end

  local args = {
    provider = fargs[1],
    profile = nil,
    model = nil,
    effort = nil,
    layout = nil,
  }

  for i = 2, #fargs do
    local key, value = parse_key_value(fargs[i])
    if not key then
      return nil, "Invalid argument: " .. fargs[i]
    end
    if key == "profile" or key == "model" or key == "effort" or key == "layout" then
      args[key] = value
    else
      return nil, "Unsupported argument key: " .. key
    end
  end

  return args
end

function M.resolve_layout(requested, tmux_context, impl_config)
  local layout = requested
  if layout ~= "auto" then
    return layout
  end

  impl_config = impl_config or config.get().implement or {}
  local tmux_settings = impl_config.tmux or {}
  local tmux_threshold = tmux_settings.min_pane_width_for_right or 140
  local fallback = (impl_config.layouts and impl_config.layouts.non_tmux) or "nvim-right"

  if tmux_context and tmux_context.available then
    if tmux_context.pane_width and tmux_context.pane_width >= tmux_threshold then
      return "tmux-right"
    end
    return "tmux-bottom"
  end
  return fallback
end

function M._tmux_layout()
  local impl = config.get().implement or {}
  if not (vim.env.TMUX and vim.fn.executable("tmux") == 1) then
    return { available = false, pane_width = 0 }
  end

  local raw = trim(table.concat(vim.fn.systemlist("tmux display-message -p '#{pane_width}'"), ""))
  local width = tonumber(raw) or 0
  return { available = width > 0, pane_width = width }
end

function M.resolve_settings(args)
  local impl = config.get().implement or {}
  local profiles = impl.profiles or {}
  local provider_cfg = M._merge_provider(args.provider)
  if vim.tbl_isempty(provider_cfg) then
    return nil, "Unknown provider: " .. args.provider
  end

  local requested_profile = args.profile
  local profile_cfg = requested_profile and profiles[requested_profile]
  local default_profile_name = impl.default_profile
  local default_profile_cfg = default_profile_name and profiles[default_profile_name]

  local model = args.model
    or (profile_cfg and profile_cfg.model)
    or (default_profile_cfg and default_profile_cfg.model)
    or provider_cfg.model
  local effort = args.effort
    or (profile_cfg and profile_cfg.effort)
    or (default_profile_cfg and default_profile_cfg.effort)
    or provider_cfg.effort
  local layout = args.layout
    or (profile_cfg and profile_cfg.layout)
    or (default_profile_cfg and default_profile_cfg.layout)
    or provider_cfg.layout
    or "auto"

  local valid_layouts = {
    ["auto"] = true,
    ["tmux-right"] = true,
    ["tmux-bottom"] = true,
    ["nvim-right"] = true,
    ["nvim-bottom"] = true,
    ["external"] = true,
    ["copy"] = true,
  }
  if not valid_layouts[layout] then
    return nil, "Unsupported layout: " .. layout
  end

  return {
    provider = args.provider,
    profile = requested_profile,
    model = model,
    effort = effort,
    layout = layout,
    provider_cfg = provider_cfg,
  }
end

local function render_template(template, context)
  local rendered = template:gsub("{([%w_]+)}", function(key)
    return context[key] or ""
  end)
  return normalize_space(rendered)
end

local function build_context_prompt(context_file)
  return table.concat({
    "Read and follow the implementation context in",
    context_file .. ".",
    "Treat that file as the source of truth for this session.",
  }, " ")
end

function M.build_provider_command(provider, settings, context_file)
  local provider_cfg = M._merge_provider(provider)
  local command_template = provider_cfg.command_template
  if not command_template or command_template == "" then
    return nil, "No command template configured for provider: " .. provider
  end

  local model_flag = provider_cfg.model_flag
  local effort_flag = provider_cfg.effort_flag
  local model = settings.model
  local effort = settings.effort

  local context_file_value = vim.fn.shellescape(context_file)
  local context_prompt_value = vim.fn.shellescape(build_context_prompt(context_file))
  local model_value = model and vim.fn.shellescape(model) or ""
  local effort_value = effort and vim.fn.shellescape(effort) or ""
  local model_flag_value = ""
  if model and model_flag then
    model_flag_value = trim(render_template(model_flag, { model = model_value }))
  end
  local effort_flag_value = ""
  if effort and effort_flag then
    effort_flag_value = trim(render_template(effort_flag, { effort = effort_value }))
  end

  local command = render_template(command_template, {
    provider = provider,
    context_file = context_file_value,
    context = context_file_value,
    context_prompt = context_prompt_value,
    model = model_value,
    effort = effort_value,
    model_flag = model_flag_value,
    effort_flag = effort_flag_value,
  })
  return command
end

function M.build_context_file(context_text)
  local tmp = vim.fn.tempname() .. ".md"
  local lines = vim.split(context_text, "\n", { plain = true })
  local ok, err = pcall(vim.fn.writefile, lines, tmp)
  if not ok then
    return nil, tostring(err)
  end
  return tmp
end

function M.preview_text(plan)
  local task = plan.task and ((plan.task.section and ("[" .. plan.task.section .. "] ") or "") .. (plan.task.text or ""))
  local label = task and trim(task) or "(none)"
  local command = plan.command
  if #command > 220 then
    command = command:sub(1, 220) .. "..."
  end
  return table.concat({
    "OpenSpecImplement launch preview",
    "",
    "Provider: " .. plan.provider,
    "Model: " .. (plan.model or "(default)"),
    "Effort: " .. (plan.effort or "(default)"),
    "Layout: " .. plan.layout,
    "Change: " .. plan.change_name,
    "Task: " .. label,
    "Context file: " .. plan.context_file,
    "",
    "Command:",
    command,
    "",
    "Launch this session now?",
  }, "\n")
end

function M._tmux_pane_title(plan)
  if plan and plan.change_name and trim(plan.change_name) ~= "" then
    return "spec: " .. to_pane_title(plan.change_name)
  end
  local provider = plan and plan.provider or "provider"
  local model = plan and plan.model or nil
  if model and model ~= "" then
    return to_pane_title(provider .. " / " .. model)
  end
  return to_pane_title(provider)
end

function M.confirm_launch(plan, opts)
  opts = opts or {}
  local confirm = opts.confirm
    or function(message)
      return vim.fn.confirm(message, "&Launch\n&Cancel", 1, "Question") == 1
    end
  return confirm(M.preview_text(plan))
end

function M._launch_tmux(plan, direction)
  local cmd = plan.command
  local direction_arg = direction == "tmux-right" and "-h" or "-v"
  local output = vim.fn.system({ "tmux", "split-window", direction_arg, "-P", "-F", "#{pane_id}", "sh", "-lc", cmd })
  if vim.v.shell_error ~= 0 then
    -- Fallback for older tmux versions that do not support `-P -F`.
    local fallback = vim.fn.system({ "tmux", "split-window", direction_arg, "sh", "-lc", cmd })
    if vim.v.shell_error ~= 0 then
      util.notify("tmux split failed: " .. trim(fallback), vim.log.levels.WARN)
      append_log("tmux split failed: " .. trim(fallback) .. " | command: " .. cmd)
      return false
    end
    append_log("tmux split success (legacy): " .. direction .. " | command: " .. cmd)
    return true
  end
  local pane_id = trim(output)
  if pane_id ~= "" then
    local pane_title = M._tmux_pane_title(plan)
    local rename_output = vim.fn.system({ "tmux", "select-pane", "-t", pane_id, "-T", pane_title })
    if vim.v.shell_error ~= 0 then
      append_log("tmux pane title set failed: " .. trim(rename_output) .. " | pane_id: " .. pane_id .. " | title: " .. pane_title)
    end
  end
  append_log("tmux split success: " .. direction .. " | command: " .. cmd)
  return true
end

function M._launch_nvim_split(plan, direction)
  local cmd = plan.command
  local origin_win = vim.api.nvim_get_current_win()
  if direction == "nvim-right" then
    vim.cmd("rightbelow vsplit")
    vim.cmd("wincmd l")
  else
    vim.cmd("rightbelow split")
    vim.cmd("wincmd j")
  end
  vim.cmd("enew")

  local job_id = vim.fn.termopen({ "sh", "-lc", cmd })
  if type(job_id) ~= "number" or job_id == 0 then
    if vim.api.nvim_win_is_valid(origin_win) then
      vim.api.nvim_set_current_win(origin_win)
    end
    util.notify("Failed to launch terminal split for command: " .. cmd, vim.log.levels.WARN)
    append_log("nvim terminal launch failed: " .. direction .. " | command: " .. cmd)
    return false
  end
  append_log("nvim terminal launch: " .. direction .. " | command: " .. cmd)
  return true
end

function M._launch_copy(plan)
  local payload = {
    "# OpenSpecImplement launch",
    "Provider: " .. plan.provider,
    "Model: " .. tostring(plan.model or "(default)"),
    "Effort: " .. tostring(plan.effort or "(default)"),
    "Command: " .. plan.command,
    "Context file: " .. plan.context_file,
  }
  vim.fn.setreg("+", table.concat(payload, "\n"))
  return true
end

function M._launch_external(plan, external_template)
  local cmd = render_template(external_template, {
    provider = plan.provider,
    command = plan.command,
    context_file = plan.context_file,
  })
  vim.fn.system(cmd)
  return true
end

function M.execute(plan, opts)
  opts = opts or {}
  if plan.layout == "copy" then
    return M._launch_copy(plan)
  end
  if plan.layout == "tmux-right" or plan.layout == "tmux-bottom" then
    if not (vim.env.TMUX and vim.fn.executable("tmux") == 1) then
      util.notify("tmux not available, falling back to Neovim split layout.")
      local fallback_layout = "nvim-right"
      return M._launch_nvim_split(plan, fallback_layout)
    end
    local launched = M._launch_tmux(plan, plan.layout)
    if not launched then
      util.notify("Falling back to Neovim split layout.")
      local fallback_layout = "nvim-right"
      return M._launch_nvim_split(plan, fallback_layout)
    end
    return true
  end
  if plan.layout == "nvim-right" or plan.layout == "nvim-bottom" then
    return M._launch_nvim_split(plan, plan.layout)
  end
  if plan.layout == "external" then
    local external_template = (config.get().implement and config.get().implement.external and config.get().implement.external.command_template) or nil
    if not external_template then
      util.notify("External launch not configured. Use OpenSpecImplement layout=copy or set implement.external.command_template.")
      return false
    end
    return M._launch_external(plan, external_template)
  end
  return false
end

function M.launch_plan(plan, opts)
  if not M.confirm_launch(plan, opts) then
    util.notify("OpenSpecImplement launch cancelled.")
    return { launched = false, cancelled = true }
  end
  local execute = opts and opts.execute or M.execute
  local launched = execute(plan)
  if not launched then
    util.notify("OpenSpecImplement launch failed for " .. plan.provider .. ".")
    return { launched = false, error = true }
  end
  util.notify("OpenSpecImplement started for " .. plan.provider .. ".")
  return { launched = true, layout = plan.layout, command = plan.command }
end

function M.start(change_name, task, context_lines, fargs, opts)
  opts = opts or {}
  local args, err = M.parse_args(fargs)
  if not args then
    util.notify(err, vim.log.levels.ERROR)
    return nil, err
  end

  local settings, settings_err = M.resolve_settings(args)
  if not settings then
    util.notify(settings_err, vim.log.levels.ERROR)
    return nil, settings_err
  end

  local layout = M.resolve_layout(settings.layout, M._tmux_layout(), config.get().implement)
  settings.layout = layout

  local context_text = table.concat(context_lines, "\n")
  local context_file, context_err = M.build_context_file(context_text)
  if not context_file then
    util.notify("Failed to create context temp file: " .. context_err, vim.log.levels.ERROR)
    return nil, context_err
  end

  local rendered_command, command_err = M.build_provider_command(args.provider, settings, context_file)
  if not rendered_command then
    util.notify("Failed to build provider command: " .. tostring(command_err), vim.log.levels.ERROR)
    return nil, tostring(command_err)
  end
  if rendered_command == "" then
    util.notify("Failed to build a valid command for provider: " .. args.provider, vim.log.levels.ERROR)
    return nil, "Failed to build provider command"
  end

  local plan = {
    provider = args.provider,
    model = settings.model,
    effort = settings.effort,
    layout = layout,
    task = task,
    change_name = change_name,
    context_file = context_file,
    command = rendered_command,
  }

  return M.launch_plan(plan, opts)
end

return M
