local config = require("openspec.config")
local context = require("openspec.context")
local discovery = require("openspec.discovery")
local health = require("openspec.health")
local html = require("openspec.html")
local tasks = require("openspec.tasks")
local ui = require("openspec.ui")
local implement = require("openspec.implement")
local util = require("openspec.util")

local M = {}

local function select_change(callback, opts)
  opts = opts or {}
  local buffer_path = vim.api.nvim_buf_get_name(0)
  local root = discovery.find_root(buffer_path)

  if not root then
    root = discovery.find_root(vim.fn.getcwd())
  end

  if not root then
    util.notify("No openspec/changes directory found from the current buffer or cwd.", vim.log.levels.WARN)
    return
  end

  local current_change = discovery.change_from_current_buffer(root)
  if current_change and not opts.always_select then
    callback(current_change)
    return
  end

  local changes = discovery.scan_active_changes(root)
  if #changes == 0 then
    util.notify("No active OpenSpec changes with tasks.md were found.", vim.log.levels.WARN)
    return
  end

  if #changes == 1 and not opts.always_select then
    callback(changes[1])
    return
  end

  vim.ui.select(changes, {
    prompt = opts.prompt or "OpenSpec change",
    format_item = function(item)
      if current_change and item.name == current_change.name then
        return item.name .. " (current)"
      end
      return item.name
    end,
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

local function with_parsed_change(callback, opts)
  select_change(function(change)
    local parsed, err = tasks.parse_change(change)
    if not parsed then
      util.notify(err, vim.log.levels.ERROR)
      return
    end

    callback(change, parsed)
  end, opts)
end

local function line_arg(params)
  if not params or not params.fargs or not params.fargs[1] then
    return nil
  end
  local lnum = tonumber(params.fargs[1])
  if not lnum then
    util.notify("Task line must be a number.", vim.log.levels.ERROR)
    return false
  end
  return lnum
end

local function show_health(change, parsed, state, opts)
  opts = opts or {}
  local win = ui.open_workspace(change, parsed, state)
  ui.set_findings_quickfix(state, { open = opts.open_quickfix })
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

function M.summary()
  if ui.close_summary() then
    return
  end

  with_parsed_change(function(change, parsed)
    ui.open_summary(change, parsed)
  end, { always_select = true, prompt = "OpenSpec summary change" })
end

function M.html()
  with_parsed_change(function(change, parsed)
    html.open(change, parsed)
  end)
end

function M.workspace()
  with_parsed_change(function(change, parsed)
    local state = health.evaluate(change, parsed, {})
    show_health(change, parsed, state)
  end)
end

local function update_task_status(change, lnum, status)
  local current = util.normalize_path(vim.api.nvim_buf_get_name(0))
  if current == change.tasks_path then
    return tasks.update_buffer_status(0, lnum, status)
  end
  return tasks.update_file_status(change.tasks_path, lnum, status)
end

local function select_task(parsed, lnum)
  if not lnum then
    return parsed.next_task
  end
  lnum = tonumber(lnum)
  if not lnum then
    return nil
  end
  for _, task in ipairs(parsed.tasks) do
    if task.lnum == lnum then
      return task
    end
  end
  return nil
end

local function refresh_parsed_change(change, fallback)
  local current = util.normalize_path(vim.api.nvim_buf_get_name(0))
  if current == change.tasks_path then
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    return tasks._parse_lines(lines, change.tasks_path, change.name), nil
  end

  local refreshed, err = tasks.parse_change(change)
  if not refreshed then
    return fallback, err
  end
  return refreshed, nil
end

function M.task_start(params)
  local lnum = line_arg(params)
  if lnum == false then
    return
  end

  with_parsed_change(function(change, parsed)
    local task = select_task(parsed, lnum)
    if not task then
      task = parsed.next_task
    end
    if not task then
      util.notify("No todo or WIP task is available.", vim.log.levels.ERROR)
      return
    end
    local result, err = update_task_status(change, task.lnum, "wip")
    if not result then
      util.notify(err, vim.log.levels.ERROR)
      return
    end
    local refreshed, parse_err = refresh_parsed_change(change, parsed)
    if parse_err then
      util.notify(parse_err, vim.log.levels.WARN)
    end
    local selected_task = select_task(refreshed, result.lnum) or {
      lnum = result.lnum,
      path = change.tasks_path,
      section = task.section,
      status = "wip",
      text = task.text,
    }
    local state = health.evaluate(change, refreshed, { task = selected_task })
    show_health(change, refreshed, state, { open_quickfix = true })
    util.notify("Task line " .. result.lnum .. " started as WIP.")
  end)
end

function M.context(params)
  local lnum = line_arg(params)
  if lnum == false then
    return
  end

  with_parsed_change(function(change, parsed)
    local selected_task = select_task(parsed, lnum)
    local state = health.evaluate(change, parsed, { task = selected_task })
    if not selected_task then
      util.notify("Context generation is best with a selected task or next todo/WIP task.", vim.log.levels.WARN)
    end
    context.open(change, parsed, state)
  end)
end

function M.implement(params)
  if not params.fargs or #params.fargs == 0 then
    util.notify("Usage: :OpenSpecImplement {provider} [profile=<name>] [model=<model>] [effort=<effort>] [layout=<layout>]", vim.log.levels.ERROR)
    return
  end

  with_parsed_change(function(change, parsed)
    local state = health.evaluate(change, parsed, { task = parsed.next_task })
    local lines = context.lines(change, parsed, state)
    local task = state.task or parsed.next_task
    implement.start(change.name, task, lines, params.fargs)
  end)
end

function M.current()
  with_parsed_change(function(change, parsed)
    local state = health.evaluate(change, parsed, {})
    local lines = {
      "Current change: " .. change.name,
      "Branch: " .. (state.git and state.git.branch or "(unknown)"),
      "Worktree: " .. (state.git and state.git.worktree or "(unknown)"),
      "Local changes: " .. tostring(#(state.git and state.git.dirty or {})),
      "CLI: " .. (state.cli and state.cli.cliAvailable and "available" or "missing"),
      "Next recommendation: " .. ((state.recommendations[1] and state.recommendations[1].command) or "none"),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "OpenSpec" })
  end)
end

local task_statuses = { "done", "todo", "wip", "skipped" }

local function complete_task_status(arg_lead, cmdline)
  if cmdline:match("^%s*OpenSpecTaskStatus%s+%S+%s+") then
    return {}
  end

  local matches = {}
  for _, status in ipairs(task_statuses) do
    if status:sub(1, #arg_lead) == arg_lead then
      table.insert(matches, status)
    end
  end
  return matches
end

function M.task_status(params)
  local status = params.fargs[1]
  local lnum = params.fargs[2]

  if not status then
    util.notify("Usage: :OpenSpecTaskStatus {done|todo|wip|skipped} [line]", vim.log.levels.ERROR)
    return
  end

  if #params.fargs > 2 then
    util.notify("Usage: :OpenSpecTaskStatus {done|todo|wip|skipped} [line]", vim.log.levels.ERROR)
    return
  end

  if lnum and not tonumber(lnum) then
    util.notify("Task line must be a number.", vim.log.levels.ERROR)
    return
  end

  local result, err = tasks.update_current_task_status(status, lnum)
  if not result then
    util.notify(err, vim.log.levels.ERROR)
    return
  end

  local suffix = result.changed and "" or " (unchanged)"
  util.notify("Task line " .. result.lnum .. " set to " .. tasks.status_label(status) .. suffix)
end

local function create_commands()
  vim.api.nvim_create_user_command("OpenSpecTasksSummary", M.summary, { force = true })
  vim.api.nvim_create_user_command("OpenSpecTasksHtml", M.html, { force = true })
  vim.api.nvim_create_user_command("OpenSpecWorkspace", M.workspace, {
    desc = "Open the OpenSpec workspace state",
    force = true,
  })
  vim.api.nvim_create_user_command("OpenSpecTaskStart", M.task_start, {
    desc = "Start the selected task as WIP",
    force = true,
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OpenSpecContext", M.context, {
    desc = "Open an upstream action context pack",
    force = true,
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OpenSpecImplement", M.implement, {
    desc = "Launch a provider implementation session with resolved model settings",
    force = true,
    nargs = "+",
  })
  vim.api.nvim_create_user_command("OpenSpecCurrent", M.current, {
    desc = "Report current OpenSpec change health",
    force = true,
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OpenSpecTaskStatus", M.task_status, {
    complete = complete_task_status,
    desc = "Set the checkbox status for the current OpenSpec task line",
    force = true,
    nargs = "+",
  })
end

local function create_keymaps()
  local mappings = config.get().mappings
  vim.keymap.set("n", mappings.summary, M.summary, { desc = "OpenSpec: Task summary" })
  vim.keymap.set("n", mappings.html, M.html, { desc = "OpenSpec: HTML change report" })
  vim.keymap.set("n", mappings.workspace, M.workspace, { desc = "OpenSpec: Workspace cockpit" })
end

function M.setup(opts)
  config.setup(opts)

  local options = config.get()
  if options.commands then
    create_commands()
  end
  if options.keymaps then
    create_keymaps()
  end
end

M.discovery = discovery
M.health = health
M.tasks = tasks

return M
