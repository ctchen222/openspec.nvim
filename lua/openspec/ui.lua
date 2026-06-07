local artifacts = require("openspec.artifacts")
local config = require("openspec.config")
local tasks = require("openspec.tasks")
local util = require("openspec.util")

local M = {}

local summary_win = nil
local workflow_win = nil

local function progress_bar(percent, width)
  local filled = math.floor((percent / 100) * width + 0.5)
  local chunks = {}

  for index = 1, width do
    if index <= filled then
      table.insert(chunks, "#")
    else
      table.insert(chunks, "-")
    end
  end

  return "[" .. table.concat(chunks) .. "]"
end

local function short_task_text(text, limit)
  text = text or ""
  if #text <= limit then
    return text
  end

  return text:sub(1, limit - 3) .. "..."
end

local function section_priority(section)
  return (section.todo * 2) + section.wip
end

local function summary_lines(parsed)
  local counts = parsed.counts
  local remaining = counts.todo + counts.wip
  local lines = {
    "OpenSpec change",
    parsed.change_name,
    "",
    string.format("%s  %d%% complete", progress_bar(parsed.percent, 34), parsed.percent),
    string.format("DONE %d/%d     LEFT %d     TODO %d     WIP %d     SKIP %d", parsed.done, parsed.total, remaining, counts.todo, counts.wip, counts.skipped),
    "",
    "NEXT ACTION",
  }

  if parsed.next_task then
    table.insert(
      lines,
      string.format(
        "  [%s] %s",
        tasks.status_label(parsed.next_task.status),
        short_task_text(parsed.next_task.text, 96)
      )
    )
  else
    table.insert(lines, "  No remaining todo or WIP tasks.")
  end

  table.insert(lines, "")
  table.insert(lines, "SECTIONS NEEDING ATTENTION")
  if remaining == 0 then
    table.insert(lines, "  All task sections are complete.")
  elseif #parsed.sections == 0 then
    table.insert(lines, "  No task sections found.")
  else
    local sections = {}
    for _, section in ipairs(parsed.sections) do
      if section.todo > 0 or section.wip > 0 then
        table.insert(sections, section)
      end
    end

    table.sort(sections, function(a, b)
      if section_priority(a) == section_priority(b) then
        return a.name < b.name
      end
      return section_priority(a) > section_priority(b)
    end)

    if #sections == 0 then
      table.insert(lines, "  No section has remaining todo or WIP tasks.")
    else
      for index, section in ipairs(sections) do
        if index > 5 then
          table.insert(lines, string.format("  ... %d more section(s). Open full report with %s", #sections - 5, config.get().mappings.html))
          break
        end

        table.insert(
          lines,
          string.format(
            "  %s  %d%% done  todo:%d  wip:%d",
            short_task_text(section.name, 58),
            util.percent(section.done, section.total),
            section.todo,
            section.wip
          )
        )
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Full report  " .. config.get().mappings.html)

  return lines
end

local function summary_window_size(lines, opts)
  local width = math.min(opts.ui.max_width, math.max(1, vim.o.columns - 8))
  width = math.max(math.min(width, vim.o.columns), math.min(74, math.max(1, vim.o.columns - 4)))

  local min_height = math.min(18, math.max(1, vim.o.lines - 6))
  local height = math.min(math.max(#lines + 2, min_height), math.max(1, vim.o.lines - 6))
  return width, height
end

local function apply_summary_highlights(buf, lines)
  local highlights = {
    [1] = "Title",
    [2] = "Directory",
    [4] = "MoreMsg",
    [5] = "Identifier",
    [7] = "WarningMsg",
    [11] = "WarningMsg",
    [#lines] = "Comment",
  }

  for line_number, group in pairs(highlights) do
    if line_number <= #lines then
      vim.api.nvim_buf_add_highlight(buf, -1, group, line_number - 1, 0, -1)
    end
  end

  for index, line in ipairs(lines) do
    if line:find("^  %[TODO%]") or line:find("todo:%d+") then
      vim.api.nvim_buf_add_highlight(buf, -1, "WarningMsg", index - 1, 0, -1)
    elseif line:find("^  %[WIP%]") or line:find("wip:%d+") then
      vim.api.nvim_buf_add_highlight(buf, -1, "Question", index - 1, 0, -1)
    end
  end
end

function M.close_summary()
  if summary_win and vim.api.nvim_win_is_valid(summary_win) then
    vim.api.nvim_win_close(summary_win, true)
    summary_win = nil
    return true
  end

  summary_win = nil
  return false
end

function M.open_summary(parsed)
  local opts = config.get()
  local lines = summary_lines(parsed)
  local width, height = summary_window_size(lines, opts)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  apply_summary_highlights(buf, lines)

  summary_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.ui.border,
    title = " OpenSpec Summary ",
    title_pos = "center",
  })
  vim.api.nvim_set_option_value("wrap", true, { win = summary_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = summary_win })
end

local function workspace_next_action(state)
  local recommendation = state and state.recommendations and state.recommendations[1]
  if recommendation then
    return recommendation.reason .. " Recommended: " .. recommendation.command
  end
  return "Inspect tasks and artifacts."
end

local function artifact_state_label(item)
  return item and item.present and "FOUND" or "MISS"
end

local function add_artifact_line(lines, label, item)
  table.insert(
    lines,
    string.format("  %-12s %-5s %s", label, artifact_state_label(item), item and item.relative_path or "(unknown)")
  )
end

local function add_artifact_digest(lines, digest)
  table.insert(lines, "")
  table.insert(lines, "Artifact digest")
  add_artifact_line(lines, "Proposal", digest.proposal)
  if digest.proposal and digest.proposal.summary and digest.proposal.summary ~= "" then
    table.insert(lines, "    " .. digest.proposal.summary)
  end
  add_artifact_line(lines, "Design", digest.design)
  table.insert(
    lines,
    string.format(
      "  %-12s %-5s %s (%d file%s)",
      "Spec deltas",
      artifact_state_label(digest.specs_dir),
      digest.specs_dir and digest.specs_dir.relative_path or "specs",
      digest.specs_count or 0,
      (digest.specs_count or 0) == 1 and "" or "s"
    )
  )
  if #(digest.specs_names or {}) > 0 then
    table.insert(lines, "    " .. table.concat(digest.specs_names, ", "))
  end
  add_artifact_line(lines, "Tasks", digest.tasks)
end

local function add_attention_sections(lines, digest)
  table.insert(lines, "")
  table.insert(lines, "Sections needing attention")
  local sections = digest.sections_needing_attention or {}
  if #sections == 0 then
    table.insert(lines, "  All task sections are complete.")
    return
  end

  for _, section in ipairs(sections) do
    table.insert(
      lines,
      string.format(
        "  %s  done:%d/%d  todo:%d  wip:%d",
        short_task_text(section.name, 58),
        section.done,
        section.total,
        section.todo,
        section.wip
      )
    )
  end
end

local function add_source_snapshot(lines, state)
  local git_info = state.git or {}
  table.insert(lines, "Git")
  table.insert(lines, "  Branch " .. (git_info.branch or "(unknown)"))
  table.insert(lines, "  Worktree " .. (git_info.worktree or "(unknown)"))
  table.insert(lines, "  Dirty entries " .. tostring(#(git_info.dirty or {})))
end

local function add_health_findings(lines, state)
  table.insert(lines, "")
  table.insert(lines, "Health findings")
  local findings = state.findings or {}
  if #findings == 0 then
    table.insert(lines, "  No findings.")
    return
  end

  for _, finding in ipairs(findings) do
    local location = ""
    if finding.path then
      location = " (" .. util.basename(finding.path)
      if finding.lnum then
        location = location .. ":" .. finding.lnum
      end
      location = location .. ")"
    end
    table.insert(lines, string.format("  %s  %s: %s%s", string.upper(finding.severity or "info"), finding.category, finding.message, location))
  end
end

local function workspace_lines(change, parsed, state)
  local selected = state.selected_task
  local cli = state.cli or {}
  local status = cli.status or {}
  local digest = artifacts.collect(change, parsed)
  local lines = {
    "OpenSpec Workspace",
    "",
    "Change  " .. change.name,
    "Tasks   " .. parsed.done .. "/" .. parsed.total .. " done (" .. parsed.percent .. "%)",
    "CLI state  " .. ((cli.cliAvailable ~= false and "available") or "degraded"),
    "Status     " .. (status.state or "unknown"),
    "Path    " .. (change.path or change.root or "(unknown)"),
    "",
    "Next action",
    "  " .. workspace_next_action(state),
    "",
    "Selected task (or next pending)",
  }

  if selected then
    table.insert(
      lines,
      string.format("  line %d  [%s]  %s", selected.lnum, tasks.status_label(selected.status), selected.text)
    )
  else
    table.insert(lines, "  No todo or WIP task selected.")
  end

  add_artifact_digest(lines, digest)
  add_attention_sections(lines, digest)

  add_source_snapshot(lines, state)
  add_health_findings(lines, state)

  return lines
end

local function workflow_window_size(lines, opts)
  local width = math.min(opts.ui.max_width, math.max(1, vim.o.columns - 8))
  width = math.max(math.min(width, vim.o.columns), math.min(82, math.max(1, vim.o.columns - 4)))
  local height = math.min(math.max(#lines + 2, 20), math.max(1, vim.o.lines - 6))
  return width, height
end

local function apply_workflow_highlights(buf, lines)
  for index, line in ipairs(lines) do
    if index == 1 then
      vim.api.nvim_buf_add_highlight(buf, -1, "Title", index - 1, 0, -1)
    elseif line:find("^  PASS") then
      vim.api.nvim_buf_add_highlight(buf, -1, "MoreMsg", index - 1, 0, -1)
    elseif line:find("^  WARN") or line:find("^  WARNING") then
      vim.api.nvim_buf_add_highlight(buf, -1, "WarningMsg", index - 1, 0, -1)
    elseif line:find("^  FAIL") or line:find("^  BLOCKER") then
      vim.api.nvim_buf_add_highlight(buf, -1, "ErrorMsg", index - 1, 0, -1)
    elseif line:find("^  LOCK") then
      vim.api.nvim_buf_add_highlight(buf, -1, "Comment", index - 1, 0, -1)
    end
  end
end

function M.close_workflow()
  if workflow_win and vim.api.nvim_win_is_valid(workflow_win) then
    vim.api.nvim_win_close(workflow_win, true)
    workflow_win = nil
    return true
  end
  workflow_win = nil
  return false
end

function M.open_workspace(change, parsed, workflow)
  M.close_workflow()
  local opts = config.get()
  local lines = workspace_lines(change, parsed, workflow)
  local width = math.min(opts.ui.max_width, math.max(40, math.floor(vim.o.columns * 0.5)))

  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, buf, "OpenSpec Workspace: " .. change.name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "openspec-workspace", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  apply_workflow_highlights(buf, lines)

  vim.cmd("botright vertical new")
  workflow_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(workflow_win, buf)
  pcall(vim.api.nvim_win_set_width, workflow_win, width)
  vim.api.nvim_set_option_value("wrap", true, { win = workflow_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = workflow_win })
  return workflow_win
end

function M.set_findings_quickfix(workflow, opts)
  opts = opts or {}
  local items = {}
  for _, finding in ipairs((workflow and workflow.findings) or {}) do
    if finding.path then
      table.insert(items, {
        filename = finding.path,
        lnum = finding.lnum or 1,
        text = string.format("[%s] %s", finding.category, finding.message),
        type = finding.severity == "blocker" and "E" or finding.severity == "warning" and "W" or "I",
      })
    end
  end
  vim.fn.setqflist({}, " ", { title = "OpenSpec local health findings", items = items })
  if #items > 0 and opts.open then
    vim.cmd.copen()
  end
  return #items
end

function M._workspace_lines(change, parsed, workflow)
  return workspace_lines(change, parsed, workflow)
end

function M._summary_lines(parsed)
  return summary_lines(parsed)
end

function M._summary_window_size(lines, opts)
  return summary_window_size(lines, opts)
end

return M
