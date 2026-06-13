local config = require("openspec.config")
local util = require("openspec.util")

local M = {}

local BUILTIN_ADAPTERS = {
  codex = {
    command_template = "codex {model_flag} {effort_flag} {initial_prompt}",
    model_flag = "--model {model}",
    effort_flag = "-c model_reasoning_effort={effort}",
    model = "gpt-5.4",
    effort = "high",
    layout = "auto",
    goal = "off",
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

local GOAL_MODES = {
  off = true,
  auto = true,
  copy = true,
}

local GOAL_PROMPT_MAX_LEN = 4000

local codex_model_catalog_cache = nil
local codex_model_catalog_error = nil

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

local function normalize_goal_mode(value)
  if value == nil then
    return nil
  end

  local normalized = value:lower()
  if normalized == "true" then
    return "auto"
  end
  if normalized == "false" then
    return "off"
  end
  if GOAL_MODES[normalized] then
    return normalized
  end

  return nil, "Unsupported goal mode: " .. value .. ". Supported values: off, auto, copy."
end

local function join_sorted(values)
  local normalized = {}
  for _, value in ipairs(values) do
    table.insert(normalized, tostring(value))
  end
  table.sort(normalized)
  return table.concat(normalized, ", ")
end

local function extract_json_blob(raw)
  local start = raw:find("%[") or raw:find("{")
  if not start then
    return nil
  end

  local opener = raw:sub(start, start)
  local closer = (opener == "[") and "]" or "}"
  local depth = 0
  local in_string = false
  local escape = false

  for i = start, #raw do
    local ch = raw:sub(i, i)

    if in_string then
      if escape then
        escape = false
      elseif ch == "\\" then
        escape = true
      elseif ch == '"' then
        in_string = false
      end
    else
      if ch == '"' then
        in_string = true
      elseif ch == opener then
        depth = depth + 1
      elseif ch == closer then
        depth = depth - 1
        if depth == 0 then
          return raw:sub(start, i)
        end
      end
    end
  end

  return raw:sub(start)
end

local function is_list_like(values)
  if type(values) ~= "table" then
    return false
  end
  if #values == 0 then
    return false
  end
  for idx = 1, #values do
    if values[idx] == nil then
      return false
    end
  end
  return true
end

local effort_field_candidates = {
  "effort",
  "reasoning_effort",
  "reasoning",
  "level",
  "name",
  "slug",
  "id",
  "value",
}

local function coerce_to_effort_value(raw_value, depth)
  depth = depth or 0
  if type(raw_value) == "string" or type(raw_value) == "number" then
    local normalized = trim(tostring(raw_value))
    if normalized ~= "" then
      return normalized
    end
  end

  if type(raw_value) ~= "table" or depth > 3 then
    return nil
  end

  for _, key in ipairs(effort_field_candidates) do
    local nested = raw_value[key]
    local normalized = coerce_to_effort_value(nested, depth + 1)
    if normalized then
      return normalized
    end
  end

  for key, nested in pairs(raw_value) do
    if key == "description" then
      goto continue
    end
    local normalized = coerce_to_effort_value(nested, depth + 1)
    if normalized then
      return normalized
    end
    ::continue::
  end

  return nil
end

local function parse_codex_model_efforts(raw)
  local efforts = {}
  if type(raw) ~= "table" then
    return efforts
  end

  for _, effort in ipairs(raw) do
    local normalized = coerce_to_effort_value(effort)
    if normalized then
      efforts[normalized] = true
    end
  end

  -- Backward compatibility: support map-style payloads like { low = true, medium = true }.
  for effort_key, supported in pairs(raw) do
    if type(effort_key) == "string" and effort_key:match("^[a-z][a-z0-9]*$") then
      if type(supported) == "table" then
        efforts[effort_key] = true
      end

      if supported == true then
        efforts[effort_key] = true
      elseif type(supported) == "table" then
        local normalized = coerce_to_effort_value(supported)
        if normalized then
          efforts[normalized] = true
        end
      elseif type(supported) == "string" or type(supported) == "number" then
        efforts[effort_key] = true
      end
    end
  end

  return efforts
end

local function normalize_model_catalog(models)
  local catalog = {}
  if type(models) ~= "table" then
    return catalog
  end

  for _, model in ipairs(models) do
    if type(model) == "table" then
      local slug = model.slug or model.name or model.model
      if slug then
        local effort_values = model.supported_reasoning_levels
          or model.supported_levels
          or model.reasoning_levels
          or model.efforts
        catalog[tostring(slug)] = parse_codex_model_efforts(effort_values)
      end
    end
  end

  return catalog
end

local function normalize_model_catalog_input(models)
  local catalog = normalize_model_catalog(models)
  if not vim.tbl_isempty(catalog) then
    return catalog
  end

  catalog = {}
  if type(models) ~= "table" then
    return catalog
  end

  for model, efforts in pairs(models) do
    if type(model) == "string" and efforts then
      local effort_values = efforts
      if type(efforts) == "table" and not is_list_like(efforts) then
        effort_values = efforts.supported_reasoning_levels
          or efforts.supported_levels
          or efforts.reasoning_levels
          or efforts.efforts
          or efforts
      end
      catalog[tostring(model)] = parse_codex_model_efforts(effort_values)
    end
  end

  return catalog
end

local function decode_codex_models(raw)
  local normalized_raw = trim(raw)
  local json_blob = extract_json_blob(normalized_raw)
  if json_blob then
    normalized_raw = json_blob
  end

  local ok, decoded = pcall(vim.json.decode, normalized_raw)
  if not ok and normalized_raw ~= raw then
    local fallback = extract_json_blob(raw)
    if not fallback then
      fallback = raw
    end
    ok, decoded = pcall(vim.json.decode, fallback)
  end
  if not ok or type(decoded) ~= "table" then
    return nil, "Unable to parse Codex model catalog response."
  end

  local models = decoded.models or decoded
  if type(models) ~= "table" then
    return nil, "Unexpected Codex model catalog shape."
  end

  local catalog = normalize_model_catalog(models)
  if vim.tbl_isempty(catalog) then
    return nil, "Codex model catalog has no supported models."
  end
  return catalog, nil
end

local function load_codex_models_from_cli()
  local commands = {
    { "codex", "debug", "models" },
    { "codex", "debug", "models", "--bundled" },
  }

  for _, command in ipairs(commands) do
    local output = vim.fn.systemlist(command)
    if vim.v.shell_error == 0 then
      local raw = table.concat(output, "\n")
      if trim(raw) ~= "" then
        local catalog, err = decode_codex_models(raw)
        if catalog then
          return catalog, nil
        end
        codex_model_catalog_error = err
      end
    else
      local msg = table.concat(output, "\n")
      if trim(msg) ~= "" then
        codex_model_catalog_error = trim(msg)
      end
    end
  end

  return nil, codex_model_catalog_error or "Unable to load Codex model catalog."
end

function M._load_codex_models(opts)
  if opts and opts.codex_models then
    return normalize_model_catalog_input(opts.codex_models), nil
  end

  if codex_model_catalog_cache then
    return codex_model_catalog_cache, nil
  end

  local catalog, err = load_codex_models_from_cli()
  if not catalog then
    return nil, err
  end

  codex_model_catalog_cache = catalog
  return catalog, nil
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
    return nil,
      "Usage: :OpenSpecImplement {provider} [profile=<name>] [model=<model>] [effort=<effort>] [layout=<auto|tmux-right|tmux-bottom|nvim-right|nvim-bottom|external|copy>] [goal=<off|auto|copy|true|false>]"
  end

  local args = {
    provider = fargs[1],
    profile = nil,
    model = nil,
    effort = nil,
    layout = nil,
    goal = nil,
  }

  for i = 2, #fargs do
    local key, value = parse_key_value(fargs[i])
    if not key then
      return nil, "Invalid argument: " .. fargs[i]
    end
    if key == "profile" or key == "model" or key == "effort" or key == "layout" or key == "goal" then
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

  local goal_candidate = args.goal
  if goal_candidate == nil then
    goal_candidate = (profile_cfg and profile_cfg.goal)
      or (default_profile_cfg and default_profile_cfg.goal)
      or impl.goal
      or provider_cfg.goal
  end
  local goal, goal_err = normalize_goal_mode(goal_candidate or "off")
  if not goal then
    return nil, goal_err
  end

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
    return nil, "Unsupported layout: " .. layout .. ". Supported layouts: auto, tmux-right, tmux-bottom, nvim-right, nvim-bottom, external, copy."
  end

  return {
    provider = args.provider,
    profile = requested_profile,
    model = model,
    effort = effort,
    layout = layout,
    goal = goal,
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

local function build_apply_invocation(change_name)
  local change_label = change_name or "this change"
  local opsx_invocation = "`/opsx:apply " .. change_label .. "`"
  return opsx_invocation
end

local function build_apply_prompt(change_name, task, context_file)
  local task_label = ""
  if task then
    task_label = table.concat({
      "Task:",
      "[" .. (task.section or "task") .. "]",
      trim(task.text or ""),
    }, " ")
  end

  local change_label = change_name or "this change"
  local apply_invocation = build_apply_invocation(change_label)
  local parts = {
    "Use",
    apply_invocation,
    "for",
    change_label .. ".",
    "Read and use the implementation context in",
    context_file .. ".",
    "Treat that file as the source of truth for this session.",
    "Start implementation now without waiting for another user confirmation.",
    "Verify with `make check` and `openspec validate --all --strict`.",
    "If requirements are missing, unrelated dirty files are detected, scope must expand,",
    "the repository state is unsafe, or verification fails, stop and request human input.",
  }

  if task_label ~= "" then
    table.insert(parts, 3, task_label)
  end

  return table.concat(parts, " ")
end

local function build_goal_objective(change_name, task, context_file)
  local change_label = change_name or "this change"
  local apply_invocation = build_apply_invocation(change_label)
  local task_line = ""
  if task then
    task_line = table.concat({
      "Selected task:",
      "[" .. (task.section or "task") .. "]",
      trim(task.text or ""),
    }, " ")
  else
    task_line = "No explicit task selected. Use the context file to identify the next task."
  end

  local parts = {
    "Implement OpenSpec change",
    change_label .. ".",
    task_line,
    "Use this command:",
    apply_invocation .. ".",
    "Read the implementation context from",
    context_file .. ".",
    "Completion criteria:",
    "context implemented, tests pass, and no unintended files are edited.",
    "Run `make check` and `openspec validate --all --strict`.",
    "Stop and request human input if requirements are missing, scope needs expansion,",
    "dirty files are unrelated, verification fails, or repo state is unsafe.",
  }

  return table.concat(parts, " ")
end

function M.build_goal_prompt(change_name, task, context_file)
  local objective = build_goal_objective(change_name, task, context_file)
  if #objective > GOAL_PROMPT_MAX_LEN then
    return nil, nil, "Goal objective exceeds Codex goal limit of " .. GOAL_PROMPT_MAX_LEN .. " chars."
  end
  return "/goal " .. objective, objective, nil
end

function M.validate_settings(settings, opts)
  if settings.provider == "codex" then
    local catalog, err = M._load_codex_models(opts)
    if not catalog then
      return nil, "Failed to validate Codex launch settings: " .. tostring(err)
    end

    local model = settings.model
    if not catalog[model] then
      local supported = {}
      for model_name in pairs(catalog) do
        table.insert(supported, model_name)
      end
      return nil, "Codex model not available: " .. tostring(model) .. ". Supported models: " .. join_sorted(supported)
    end

    local supported_efforts = catalog[model]
    local effort = tostring(settings.effort)
    if not supported_efforts[effort] then
      local effort_values = {}
      for effort_value in pairs(supported_efforts) do
        table.insert(effort_values, effort_value)
      end
      local normalized_attempts = join_sorted(effort_values)
      if #effort_values == 0 then
        return nil, "Unsupported Codex effort '" .. effort .. "' for model " .. tostring(model) .. ". No reasoning effort metadata found for this model."
      end
      return nil,
        "Unsupported Codex effort '" .. effort .. "' for model " .. tostring(model) .. ". " ..
        "Available efforts for this model: " .. normalized_attempts
    end
    return true
  end

  if settings.goal and settings.goal ~= "off" then
    return nil, "Goal handoff is only supported for provider 'codex'."
  end

  return true
end

function M.build_provider_command(provider, settings, context_file)
  local provider_cfg = M._merge_provider(provider)
  local command_template = provider_cfg.command_template
  if not command_template or command_template == "" then
    return nil, "No command template configured for provider: " .. provider
  end

  local has_initial_prompt = command_template:find("{initial_prompt}") ~= nil
  local has_context_prompt = command_template:find("{context_prompt}") ~= nil
  local has_goal_prompt = command_template:find("{goal_prompt}") ~= nil
  if settings.provider == "codex" and not (has_initial_prompt or has_context_prompt or has_goal_prompt) then
    return nil, "Provider template must include {initial_prompt}, {context_prompt}, or {goal_prompt} for Codex launch."
  end
  if settings.provider == "codex" and settings.goal == "auto" and not (has_initial_prompt or has_goal_prompt) then
    return nil, "Codex goal=auto requires {initial_prompt} or {goal_prompt} in the command template."
  end

  local model_flag = provider_cfg.model_flag
  local effort_flag = provider_cfg.effort_flag
  local model = settings.model
  local effort = settings.effort
  local change_name = settings.change_name or "this change"
  local task = settings.task
  local goal_mode = settings.goal or "off"
  local goal_prompt = settings.goal_prompt

  if goal_mode == "auto" and not goal_prompt then
    return nil, "Goal mode auto requires a generated goal prompt."
  end

  local apply_prompt = build_apply_prompt(change_name, task, context_file)
  local initial_prompt = apply_prompt
  if goal_mode == "auto" and goal_prompt then
    initial_prompt = goal_prompt
  end

  local context_prompt = build_context_prompt(context_file)
  if provider == "codex" then
    context_prompt = apply_prompt
  end

  local context_file_value = vim.fn.shellescape(context_file)
  local context_prompt_value = vim.fn.shellescape(context_prompt)
  local initial_prompt_value = vim.fn.shellescape(initial_prompt)
  local goal_prompt_value = goal_prompt and vim.fn.shellescape(goal_prompt) or ""
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
    initial_prompt = initial_prompt_value,
    goal_prompt = goal_prompt_value,
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
  local goal_summary = plan.goal_summary
  if goal_summary and #goal_summary > 160 then
    goal_summary = goal_summary:sub(1, 160) .. "..."
  end
  return table.concat({
    "OpenSpecImplement launch preview",
    "",
    "Provider: " .. plan.provider,
    "Model: " .. (plan.model or "(default)"),
    "Effort: " .. (plan.effort or "(default)"),
    "Goal mode: " .. (plan.goal_mode or "off"),
    "Layout: " .. plan.layout,
    "Change: " .. plan.change_name,
    "Task: " .. label,
    "Context file: " .. plan.context_file,
    goal_summary and ("Goal objective: " .. goal_summary) or "Goal objective: (not enabled)",
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
  if plan.goal_mode and plan.goal_mode ~= "off" and plan.goal_command then
    local payload = {
      "# OpenSpecImplement goal fallback",
      "Goal command: " .. plan.goal_command,
    }
    vim.fn.setreg("+", table.concat(payload, "\n"))
    return true
  end

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

  if plan.goal_mode and plan.goal_mode ~= "off" and plan.goal_command then
    local ok, err = pcall(vim.fn.setreg, "+", plan.goal_command)
    if not ok then
      if plan.goal_mode == "auto" then
        util.notify("Goal handoff copy failed, continuing launch.", vim.log.levels.WARN)
      else
        util.notify("Goal handoff copy failed: " .. tostring(err), vim.log.levels.WARN)
      end
      append_log("Goal handoff copy failed: " .. tostring(err))
    end
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

  local valid, valid_err = M.validate_settings(settings, opts)
  if not valid then
    util.notify(valid_err, vim.log.levels.ERROR)
    return nil, valid_err
  end

  local layout = M.resolve_layout(settings.layout, M._tmux_layout(), config.get().implement)
  settings.layout = layout

  local context_text = table.concat(context_lines, "\n")
  local context_file, context_err = M.build_context_file(context_text)
  if not context_file then
    util.notify("Failed to create context temp file: " .. context_err, vim.log.levels.ERROR)
    return nil, context_err
  end

  settings.change_name = change_name
  settings.task = task

  local goal_command = nil
  local goal_summary = nil
  if settings.goal ~= "off" then
    local err_goal
    goal_command, goal_summary, err_goal = M.build_goal_prompt(change_name, task, context_file)
    if not goal_command then
      util.notify(err_goal, vim.log.levels.ERROR)
      return nil, err_goal
    end
    settings.goal_prompt = goal_command
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
    goal_mode = settings.goal,
    goal_command = goal_command,
    goal_summary = goal_summary,
  }

  return M.launch_plan(plan, opts)
end

return M
