local config = require("openspec.config")
local util = require("openspec.util")

local M = {}

local STATUS_LABELS = {
  done = "DONE",
  skipped = "SKIP",
  todo = "TODO",
  wip = "WIP",
}

local function new_section(name, level)
  return {
    name = name,
    level = level,
    done = 0,
    skipped = 0,
    todo = 0,
    total = 0,
    wip = 0,
  }
end

local function add_task_to_section(section, status)
  local opts = config.get()
  if status == "skipped" and not opts.tasks.include_skipped_in_total then
    section.skipped = section.skipped + 1
    return
  end

  section.total = section.total + 1
  if status == "done" then
    section.done = section.done + 1
  elseif status == "wip" then
    section.wip = section.wip + 1
  elseif status == "skipped" then
    section.skipped = section.skipped + 1
  else
    section.todo = section.todo + 1
  end
end

function M.status_label(status)
  return STATUS_LABELS[status] or "TODO"
end

local function status_checkbox(status)
  local chars = config.get().tasks.statuses[status]
  if not chars or not chars[1] then
    return nil
  end
  return chars[1]
end

local TASK_COMMENT_PATTERN = "<!%-%-.+%-%->"

local function strip_task_id_comment(text)
  return (text:gsub("%s*" .. TASK_COMMENT_PATTERN, "")):gsub("%s+$", "")
end

local function task_text_from_line(line)
  local text = line:match("^%s*[-*+]%s+%[[^%]]%]%s*(.*)$")
  if not text then
    return nil
  end
  return strip_task_id_comment(text)
end

function M.task_text_from_line(line)
  return task_text_from_line(line)
end

function M._replace_status_line(line, status)
  local checkbox = status_checkbox(status)
  if not checkbox then
    return nil, "Unknown task status: " .. tostring(status)
  end

  local prefix, suffix = line:match("^(%s*[-*+]%s+%[)[^%]](%]%s*.*)$")
  if not prefix then
    return nil, "Line is not an OpenSpec checkbox task."
  end

  return prefix .. checkbox .. suffix, nil
end

function M.update_buffer_status(bufnr, lnum, status)
  bufnr = bufnr or 0
  lnum = tonumber(lnum)

  if not lnum or lnum < 1 or lnum > vim.api.nvim_buf_line_count(bufnr) then
    return nil, "Task line is out of range."
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
  local updated, err = M._replace_status_line(line, status)
  if not updated then
    return nil, err
  end

  if updated ~= line then
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { updated })
  end

  return {
    changed = updated ~= line,
    line = updated,
    lnum = lnum,
    status = status,
  }, nil
end

function M.update_file_status(path, lnum, status, opts)
  opts = opts or {}
  path = util.normalize_path(path)
  lnum = tonumber(lnum)

  if path == "" or not util.is_file(path) then
    return nil, "Task file does not exist."
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "Could not read " .. path
  end

  if not lnum or lnum < 1 or lnum > #lines then
    return nil, "Task line is out of range."
  end

  local line = lines[lnum]
  local current_text = task_text_from_line(line)
  if opts.expected_text and current_text ~= opts.expected_text then
    return nil, "Task line changed before status update."
  end

  local updated, err = M._replace_status_line(line, status)
  if not updated then
    return nil, err
  end

  if updated ~= line then
    lines[lnum] = updated
    local write_ok, write_result = pcall(vim.fn.writefile, lines, path)
    if not write_ok or write_result ~= 0 then
      return nil, "Could not write " .. path
    end
  end

  return {
    changed = updated ~= line,
    line = updated,
    lnum = lnum,
    path = path,
    status = status,
  }, nil
end

function M.update_current_task_status(status, lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local path = util.normalize_path(vim.api.nvim_buf_get_name(bufnr))

  if path == "" then
    return nil, "Current buffer is not a file."
  end

  if util.basename(path) ~= config.get().openspec.tasks_file then
    return nil, "Open an OpenSpec tasks.md buffer before changing task status."
  end

  return M.update_buffer_status(bufnr, lnum or vim.api.nvim_win_get_cursor(0)[1], status)
end

function M._parse_lines(lines, tasks_path, change_name)
  local status_lookup = config.status_lookup()
  local sections = {}
  local current_section = new_section("Unsectioned", 0)
  table.insert(sections, current_section)

  local tasks = {}
  local counts = {
    done = 0,
    skipped = 0,
    todo = 0,
    wip = 0,
  }

  for line_number, line in ipairs(lines) do
    local heading_marks, heading_text = line:match("^(#+)%s+(.+)$")
    if heading_marks and heading_text then
      heading_text = heading_text:gsub("%s+#*$", "")
      current_section = new_section(heading_text, #heading_marks)
      table.insert(sections, current_section)
    end

    local checkbox, text = line:match("^%s*[-*+]%s+%[([^%]])%]%s*(.*)$")
    if checkbox then
      text = strip_task_id_comment(text)
      local status = status_lookup[checkbox] or "todo"
      counts[status] = counts[status] + 1
      add_task_to_section(current_section, status)

      table.insert(tasks, {
        lnum = line_number,
        path = tasks_path,
        section = current_section.name,
        status = status,
        text = text,
      })
    end
  end

  local opts = config.get()
  local actionable_total = counts.done + counts.todo + counts.wip
  if opts.tasks.include_skipped_in_total then
    actionable_total = actionable_total + counts.skipped
  end

  local next_task = nil
  for _, task in ipairs(tasks) do
    if task.status == "todo" or task.status == "wip" then
      next_task = task
      break
    end
  end

  local visible_sections = {}
  for _, section in ipairs(sections) do
    if section.total > 0 or section.skipped > 0 then
      table.insert(visible_sections, section)
    end
  end

  return {
    change_name = change_name,
    counts = counts,
    done = counts.done,
    next_task = next_task,
    path = tasks_path,
    percent = util.percent(counts.done, actionable_total),
    sections = visible_sections,
    tasks = tasks,
    total = actionable_total,
  }
end

function M.parse_change(change)
  local ok, lines = pcall(vim.fn.readfile, change.tasks_path)
  if not ok then
    return nil, "Could not read " .. change.tasks_path
  end

  return M._parse_lines(lines, change.tasks_path, change.name), nil
end

return M
