local artifacts = require("openspec.artifacts")
local config = require("openspec.config")
local tasks = require("openspec.tasks")
local util = require("openspec.util")

local M = {}

local summary_win = nil
local workflow_win = nil
local archive_search_win = nil
local archive_detail_win = nil

local MAX_ARCHIVE_SEARCH_CHANGES = 25
local MAX_ARCHIVE_SEARCH_SNIPPETS = 5

local summary_buffer_state = {}
local archive_search_buffer_state = {}
local archive_detail_buffer_state = {}

local function trim_text(text, max_length)
  if not text then
    return ""
  end
  text = tostring(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if #text <= max_length then
    return text
  end
  return text:sub(1, max_length - 3) .. "..."
end

local function set_buffer_state(store, buf, state)
  if buf and buf > 0 then
    store[buf] = state
  end
end

local function delete_buffer_state(store, buf)
  if store[buf] then
    store[buf] = nil
  end
end

local function get_buffer_state(store, buf)
  return store[buf]
end

local function notify_not_found(kind, change_name)
  util.notify(string.format("Archived artifact not available: %s (%s).", change_name or "Unknown change", kind or "artifact"), vim.log.levels.WARN)
end

local function file_exists(path)
  return path ~= "" and util.is_file(path)
end

local function normalize_change(change)
  return {
    name = change.name or util.basename(change.path or ""),
    path = util.normalize_path(change.path or ""),
    archive_name = change.archive_name or util.basename(change.path or ""),
    archive_date = change.archive_date,
    tasks_path = util.normalize_path(change.tasks_path or ""),
    source_path = change.source_path or "",
  }
end

local function artifact_key_label(artifact_kind)
  if artifact_kind == "proposal" then
    return "proposal"
  end
  if artifact_kind == "design" then
    return "design"
  end
  if artifact_kind == "tasks" then
    return "tasks"
  end
  if artifact_kind == "specs" or artifact_kind == "spec" then
    return "spec"
  end
  return artifact_kind
end

local function extract_archive_source(change, root)
  if change.source_path and change.source_path ~= "" then
    return change.source_path
  end
  local opts = config.get()
  local normalized = util.normalize_path(util.join_path(root or "", opts.openspec.changes_dir, change.name or "")) -- fallback
  return normalized
end

local function format_archive_source(change)
  local path = change.source_path or ""
  if path ~= "" then
    return path
  end
  return change.path or ""
end

local function artifact_source_window(buf)
  local state = get_buffer_state(archive_search_buffer_state, buf)
  if not state and (buf == vim.api.nvim_get_current_buf()) then
    state = get_buffer_state(summary_buffer_state, buf)
  end
  if not state then
    state = get_buffer_state(archive_detail_buffer_state, buf)
  end
  if state and state.source_window and vim.api.nvim_win_is_valid(state.source_window) then
    return state.source_window
  end
  return vim.api.nvim_get_current_win()
end

local function open_in_window(path, lnum, source_window)
  if not file_exists(path) then
    return false
  end

  local win = artifact_source_window(vim.api.nvim_get_current_buf())
  if source_window and vim.api.nvim_win_is_valid(source_window) then
    win = source_window
  end
  if not win or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end

  local ok = pcall(function()
    vim.api.nvim_set_current_win(win)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    if lnum and lnum >= 1 then
      local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
      local safe_line = math.max(1, math.min(lnum, line_count))
      vim.api.nvim_win_set_cursor(win, { safe_line, 0 })
    end
  end)
  return ok
end

local function open_artifact_target(target, source_window, change_name)
  if not target or not file_exists(target.absolute_path or target.path) then
    notify_not_found(artifact_key_label(target and target.kind or nil), change_name)
    return false
  end
  return open_in_window(target.absolute_path or target.path, target.lnum, source_window)
end

local function open_artifact_from_change(change, kind, source_window, opts)
  opts = opts or {}
  local close_archive_views = opts.close_archive_views == true
  local close_summary = opts.close_summary == true

  local candidates = artifacts.resolve_artifact_targets(change, kind)
  if #candidates == 0 then
    notify_not_found(artifact_key_label(kind), change.name)
    return false
  end

  if kind == "specs" and #candidates > 1 then
    local options = vim.tbl_map(function(item)
      return {
        text = item.label or item.relative_path,
        value = item,
      }
    end, candidates)

    vim.ui.select(options, {
      prompt = "Select spec artifact",
      format_item = function(item)
        return item.text .. " (" .. (item.relative_path or item.path) .. ")"
      end,
    }, function(choice)
      if choice and choice.value then
        local opened = open_artifact_target(choice.value, source_window, change.name)
        if opened and close_archive_views then
          M.close_archive_views()
        end
        if opened and close_summary then
          M.close_summary()
        end
      end
    end)
    return true
  end

  local opened = open_artifact_target(candidates[1], source_window, change.name)
  if opened and close_archive_views then
    M.close_archive_views()
  end
  if opened and close_summary then
    M.close_summary()
  end
  return opened
end

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

local function artifact_flag(item)
  return item and item.present and "FOUND" or "MISS"
end

local function summary_state(parsed, digest)
  local missing = {}
  if not (digest.proposal and digest.proposal.present) then
    table.insert(missing, "proposal")
  end
  if not (digest.design and digest.design.present) then
    table.insert(missing, "design")
  end
  if not (digest.specs_dir and digest.specs_dir.present) then
    table.insert(missing, "spec delta")
  end
  if not (digest.tasks and digest.tasks.present) then
    table.insert(missing, "tasks")
  end

  if #missing > 0 then
    return "NEEDS ARTIFACTS", "missing " .. table.concat(missing, ", ")
  end
  if parsed.total == 0 then
    return "NO TASKS", "tasks.md has no parsed checkbox tasks"
  end
  if parsed.counts.wip > 0 then
    return "IN PROGRESS", tostring(parsed.counts.wip) .. " task(s) marked WIP"
  end
  if parsed.counts.todo > 0 then
    return "PLANNED", tostring(parsed.counts.todo) .. " task(s) still todo"
  end
  return "READY TO VERIFY", "all parsed tasks are done or skipped"
end

local function summary_upstream_action(change_name, parsed)
  if parsed.total > 0 and parsed.counts.todo == 0 and parsed.counts.wip == 0 then
    return "/opsx:verify " .. change_name
  end
  return "/opsx:apply " .. change_name
end

local function summary_lines(change, parsed)
  local counts = parsed.counts
  local remaining = counts.todo + counts.wip
  local digest = artifacts.collect(change, parsed)
  local state_label, state_reason = summary_state(parsed, digest)
  local lines = {
    "OpenSpec Summary",
    parsed.change_name,
    "",
    "SPEC STATE",
    "  " .. state_label .. "  " .. state_reason,
    string.format(
      "  Artifacts  proposal:%s  design:%s  specs:%s  tasks:%s",
      artifact_flag(digest.proposal),
      artifact_flag(digest.design),
      artifact_flag(digest.specs_dir),
      artifact_flag(digest.tasks)
    ),
    string.format(
      "  Spec deltas  %d file%s%s",
      digest.specs_count or 0,
      (digest.specs_count or 0) == 1 and "" or "s",
      #(digest.specs_names or {}) > 0 and ("  " .. table.concat(digest.specs_names, ", ")) or ""
    ),
    "",
    "TASK PROGRESS",
    string.format("%s  %d%% complete", progress_bar(parsed.percent, 34), parsed.percent),
    string.format("DONE %d/%d     LEFT %d     TODO %d     WIP %d     SKIP %d", parsed.done, parsed.total, remaining, counts.todo, counts.wip, counts.skipped),
    "",
    "NEXT TASK",
  }

  if parsed.next_task then
    table.insert(
      lines,
      string.format(
        "  line %d  [%s] %s",
        parsed.next_task.lnum,
        tasks.status_label(parsed.next_task.status),
        short_task_text(parsed.next_task.text, 96)
      )
    )
  else
    table.insert(lines, "  No remaining todo or WIP tasks.")
  end

  table.insert(lines, "")
  table.insert(lines, "NEXT UPSTREAM ACTION")
  table.insert(lines, "  " .. summary_upstream_action(parsed.change_name, parsed))
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
  table.insert(lines, "Workspace  " .. config.get().mappings.workspace .. "    Full report  " .. config.get().mappings.html)
  table.insert(lines, "Keys: p proposal  d design  t tasks  s spec")

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
    [4] = "Identifier",
    [10] = "MoreMsg",
    [11] = "Identifier",
    [13] = "WarningMsg",
    [#lines] = "Comment",
  }

  for line_number, group in pairs(highlights) do
    if line_number <= #lines then
      vim.api.nvim_buf_add_highlight(buf, -1, group, line_number - 1, 0, -1)
    end
  end

  for index, line in ipairs(lines) do
    if line:find("READY TO VERIFY", 1, true) then
      vim.api.nvim_buf_add_highlight(buf, -1, "MoreMsg", index - 1, 0, -1)
    elseif line:find("IN PROGRESS", 1, true) then
      vim.api.nvim_buf_add_highlight(buf, -1, "Question", index - 1, 0, -1)
    elseif line:find("NEEDS ARTIFACTS", 1, true) or line:find("MISS", 1, true) then
      vim.api.nvim_buf_add_highlight(buf, -1, "ErrorMsg", index - 1, 0, -1)
    elseif line:find("^  %[TODO%]") or line:find("todo:%d+") then
      vim.api.nvim_buf_add_highlight(buf, -1, "WarningMsg", index - 1, 0, -1)
    elseif line:find("^  %[WIP%]") or line:find("wip:%d+") then
      vim.api.nvim_buf_add_highlight(buf, -1, "Question", index - 1, 0, -1)
    end
  end
end

local function install_summary_keymaps(buf, change, source_window)
  local options = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "p", function()
    open_artifact_from_change(change, "proposal", source_window, { close_summary = true })
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: Open proposal artifact" }))
  vim.keymap.set("n", "d", function()
    open_artifact_from_change(change, "design", source_window, { close_summary = true })
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: Open design artifact" }))
  vim.keymap.set("n", "t", function()
    open_artifact_from_change(change, "tasks", source_window, { close_summary = true })
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: Open tasks artifact" }))
  vim.keymap.set("n", "s", function()
    open_artifact_from_change(change, "specs", source_window, { close_summary = true })
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: Open spec artifacts" }))
end

local function install_close_keymap(buf, close_fn)
  local options = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "q", close_fn, vim.tbl_extend("force", options, { desc = "OpenSpec: close buffer" }))
end

local function line_matches_query(line, query)
  if not query or query == "" then
    return nil
  end
  local lower_line = line:lower()
  local lower_query = query:lower()
  local start_col = lower_line:find(lower_query, 1, true)
  if not start_col then
    return nil
  end
  return start_col - 1, start_col + #query - 1
end

local function archive_change_key_hint(query)
  if query and query ~= "" then
    return "Keys: <Enter> detail  p proposal  d design  t tasks  s spec  q close  (query: " .. query .. ")"
  end
  return "Keys: <Enter> detail  p proposal  d design  t tasks  s spec  q close"
end

local function archive_detail_key_hint()
  return "Keys: p proposal  d design  t tasks  s spec  q close"
end

local function archive_search_result_status(change)
  local artifact_targets = {
    artifacts.resolve_artifact_targets(change, "proposal")[1],
    artifacts.resolve_artifact_targets(change, "design")[1],
    artifacts.resolve_artifact_targets(change, "tasks")[1],
    artifacts.resolve_artifact_targets(change, "specs")[1],
  }
  local present = {}
  present[1] = (artifact_targets[1] and artifact_targets[1].present) and "proposal:FOUND" or "proposal:MISS"
  present[2] = (artifact_targets[2] and artifact_targets[2].present) and "design:FOUND" or "design:MISS"
  present[3] = (artifact_targets[3] and artifact_targets[3].present) and "tasks:FOUND" or "tasks:MISS"
  present[4] = (artifact_targets[4] and artifact_targets[4].present) and "specs:FOUND" or "specs:MISS"
  return present[1], present[2], present[3], present[4]
end

local function collect_lines_by_query(change, query)
  local groups = {
    proposal = {},
    design = {},
    tasks = {},
    specs = {},
  }

  if query == "" then
    return groups
  end

  local lower_query = query:lower()
  local artifact_map = {
    proposal = artifacts.resolve_artifact_targets(change, "proposal")[1],
    design = artifacts.resolve_artifact_targets(change, "design")[1],
    tasks = artifacts.resolve_artifact_targets(change, "tasks")[1],
  }
  local specs = artifacts.resolve_artifact_targets(change, "specs")

  local function collect_for_target(label, target)
    if not target or not target.content then
      return
    end
    local lines = vim.split(target.content, "\n", { plain = true })
    local found = 0
    for idx, line in ipairs(lines) do
      local line_text = line or ""
      if line_text:lower():find(lower_query, 1, true) then
        found = found + 1
        table.insert(groups[label], {
          kind = "artifact",
          target = target,
          lnum = idx,
          path = target.absolute_path,
          display = target.display_path,
          snippet = trim_text(line_text:gsub("`", ""), 140),
          line_no = idx,
        })
      end
    end
    return found
  end

  collect_for_target("proposal", artifact_map.proposal)
  collect_for_target("design", artifact_map.design)
  collect_for_target("tasks", artifact_map.tasks)

  for _, spec in ipairs(specs) do
    if spec and spec.content then
      local lines = vim.split(spec.content, "\n", { plain = true })
      for idx, line in ipairs(lines) do
        if line:lower():find(lower_query, 1, true) then
          table.insert(groups.specs, {
            kind = "artifact",
            target = spec,
            lnum = idx,
            path = spec.absolute_path,
            display = spec.display_path,
            snippet = trim_text(line:gsub("`", ""), 140),
            line_no = idx,
          })
        end
      end
    end
  end

  return groups
end

local function parse_task_excerpt(parsed)
  if not parsed or not parsed.tasks then
    return "No task excerpt available."
  end

  local rows = {}
  for _, task in ipairs(parsed.tasks) do
    if task.text then
      table.insert(rows, task.text)
      if #rows >= 2 then
        break
      end
    end
  end

  if #rows == 0 then
    return "No task excerpt available."
  end
  return table.concat(rows, " / ")
end

function M.close_summary()
  if summary_win and vim.api.nvim_win_is_valid(summary_win) then
    local buf = vim.api.nvim_win_get_buf(summary_win)
    delete_buffer_state(summary_buffer_state, buf)
    vim.api.nvim_win_close(summary_win, true)
    summary_win = nil
    return true
  end

  local buf = vim.api.nvim_get_current_buf()
  delete_buffer_state(summary_buffer_state, buf)
  summary_win = nil
  return false
end
 
function M.open_summary(change, parsed)
  local opts = config.get()
  local lines = summary_lines(change, parsed)
  local width, height = summary_window_size(lines, opts)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  local source_window = vim.api.nvim_get_current_win()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  apply_summary_highlights(buf, lines)
  set_buffer_state(summary_buffer_state, buf, { source_window = source_window, change = change })
  install_summary_keymaps(buf, change, source_window)

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

local function build_archive_search_lines(changes, query)
  local lines = { "OpenSpec Archive Search", "" }
  local line_metadata = {}
  local has_query = query and query ~= ""
  local total_changes = #changes
  local render_changes = {}

  for index, change in ipairs(changes) do
    table.insert(render_changes, normalize_change(change))
    if #render_changes >= MAX_ARCHIVE_SEARCH_CHANGES then
      break
    end
  end

  table.insert(lines, archive_change_key_hint(query))
  table.insert(lines, "Archive dir  openspec/changes/archive")
  table.insert(lines, "")

  if total_changes == 0 then
    table.insert(lines, "No archived changes found.")
    return lines, line_metadata, 0, 0, false
  end

  local line_number = #lines + 1
  local matched_changes = 0
  for _, change in ipairs(render_changes) do
    local proposal_status, design_status, tasks_status, specs_status = archive_search_result_status(change)
    local header = "Change: " .. change.name
    if change.archive_date then
      header = header .. "  [" .. change.archive_date .. "]"
    end
    table.insert(lines, header)
    line_metadata[line_number] = { kind = "detail", change = change }
    line_number = line_number + 1

    table.insert(lines, "  " .. format_archive_source(change))
    line_metadata[line_number] = { kind = "detail", change = change }
    line_number = line_number + 1

    table.insert(lines, string.format("  %s  %s  %s  %s", proposal_status, design_status, specs_status, tasks_status))
    line_metadata[line_number] = { kind = "detail", change = change }
    line_number = line_number + 1

    if has_query then
      local groups = collect_lines_by_query(change, query)
      local snippet_lines = 0
      local matched = false
      local order = {
        { key = "proposal", label = "Proposal" },
        { key = "design", label = "Design" },
        { key = "tasks", label = "Tasks" },
        { key = "specs", label = "Specs" },
      }

      for _, item in ipairs(order) do
        local matches = groups[item.key]
        if #matches > 0 then
          matched = true
          matched_changes = matched_changes + 1
          table.insert(lines, "  " .. item.label .. " matches")
          line_metadata[line_number] = { kind = "detail", change = change }
          line_number = line_number + 1
          for _, match in ipairs(matches) do
            if snippet_lines >= MAX_ARCHIVE_SEARCH_SNIPPETS then
              table.insert(lines, "    ... more matches for this change")
              line_metadata[line_number] = { kind = "detail", change = change }
              line_number = line_number + 1
              break
            end
            snippet_lines = snippet_lines + 1
            local line_text = string.format("    %s:%d %s", match.display, match.line_no, match.snippet)
            local start, stop = line_matches_query(line_text, query)
            table.insert(lines, line_text)
            line_metadata[line_number] = {
              kind = "artifact",
              change = change,
              target = match.target,
              lnum = match.lnum,
            }
            if start and stop then
              line_metadata[line_number].highlight = {
                start = start,
                stop = stop + 1,
              }
            end
            line_number = line_number + 1
          end
        end
      end

      if not matched then
        table.insert(lines, "    No matches in this change.")
        line_metadata[line_number] = { kind = "detail", change = change }
        line_number = line_number + 1
      end
    else
      table.insert(lines, "")
      line_metadata[line_number] = { kind = "detail", change = change }
      line_number = line_number + 1
    end
  end

  if total_changes > #render_changes then
    table.insert(lines, "")
    table.insert(
      lines,
      string.format("Found %d archived changes. Showing %d. Use a more specific query.", total_changes, #render_changes)
    )
  end

  if has_query and matched_changes == 0 then
    table.insert(lines, "")
    table.insert(lines, "No matches. Try a shorter query or run :OpenSpecArchiveSearch without a query.")
  end

  return lines, line_metadata, matched_changes
end

local function archive_search_result_meta(buf, line_no)
  local state = get_buffer_state(archive_search_buffer_state, buf)
  if not state or not state.line_metadata then
    return nil
  end

  local metadata = state.line_metadata[line_no]
  local current = line_no
  while not metadata and current > 0 do
    current = current - 1
    metadata = state.line_metadata[current]
  end
  return metadata
end

local function install_archive_search_keymaps(buf)
  local function open_from_cursor(kind)
    local line_no = vim.api.nvim_win_get_cursor(0)[1]
    local metadata = archive_search_result_meta(buf, line_no)
    local state = get_buffer_state(archive_search_buffer_state, buf)
    if not metadata or not metadata.change then
      return
    end
    open_artifact_from_change(metadata.change, kind, state and state.source_window, { close_archive_views = true })
  end

  local function open_enter()
    local line_no = vim.api.nvim_win_get_cursor(0)[1]
    local metadata = archive_search_result_meta(buf, line_no)
    local state = get_buffer_state(archive_search_buffer_state, buf)
    if not metadata or not metadata.change then
      return
    end
    if metadata.kind == "artifact" and metadata.target then
      local opened = open_artifact_target(metadata.target, state and state.source_window, metadata.change.name)
      if opened then
        M.close_archive_views()
      end
      return
    end
    if metadata.kind == "detail" then
      M.open_archive_detail(metadata.change)
    end
  end

  local options = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "<CR>", open_enter, vim.tbl_extend("force", options, { desc = "OpenSpec: open archive result" }))
  vim.keymap.set("n", "p", function()
    open_from_cursor("proposal")
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: archive proposal" }))
  vim.keymap.set("n", "d", function()
    open_from_cursor("design")
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: archive design" }))
  vim.keymap.set("n", "t", function()
    open_from_cursor("tasks")
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: archive tasks" }))
  vim.keymap.set("n", "s", function()
    open_from_cursor("specs")
  end, vim.tbl_extend("force", options, { desc = "OpenSpec: archive specs" }))
  install_close_keymap(buf, function()
    M.close_archive_search()
  end)
end

local function apply_archive_search_highlights(buf, lines, line_metadata, query)
  for line_number, line in ipairs(lines) do
    if line_number == 1 then
      vim.api.nvim_buf_add_highlight(buf, -1, "Title", line_number - 1, 0, -1)
    elseif line:find("^  %[[0-9]+", 1) then
      vim.api.nvim_buf_add_highlight(buf, -1, "Question", line_number - 1, 0, -1)
    end
  end
  if not query or query == "" then
    return
  end
  for line_no, metadata in pairs(line_metadata) do
    if metadata.highlight then
      vim.api.nvim_buf_add_highlight(buf, -1, "Search", line_no - 1, metadata.highlight.start, metadata.highlight.stop)
    end
  end
end

function M.close_archive_search()
  if archive_search_win and vim.api.nvim_win_is_valid(archive_search_win) then
    local buf = vim.api.nvim_win_get_buf(archive_search_win)
    delete_buffer_state(archive_search_buffer_state, buf)
    vim.api.nvim_win_close(archive_search_win, true)
    archive_search_win = nil
    return true
  end
  archive_search_win = nil
  return false
end

function M.close_archive_views()
  local detail_closed = M.close_archive_detail()
  local search_closed = M.close_archive_search()
  return detail_closed or search_closed
end

function M.open_archive_search(changes, query)
  if M.close_archive_search() then
    -- Keep a deterministic toggle for callers that call open directly.
    return nil
  end
  local opts = config.get()
  local source_window = vim.api.nvim_get_current_win()
  local lines, line_metadata = build_archive_search_lines(changes, query or "")

  local width, height = summary_window_size(lines, opts)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "openspec-archive-search", { buf = buf })
  apply_archive_search_highlights(buf, lines, line_metadata, query or "")
  set_buffer_state(archive_search_buffer_state, buf, {
    source_window = source_window,
    line_metadata = line_metadata,
    query = query,
  })

  archive_search_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.ui.border,
    title = " OpenSpec Archive Search ",
    title_pos = "center",
  })
  install_archive_search_keymaps(buf)
  vim.api.nvim_set_option_value("wrap", true, { win = archive_search_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = archive_search_win })
  return archive_search_win
end

function M.close_archive_detail()
  if archive_detail_win and vim.api.nvim_win_is_valid(archive_detail_win) then
    local buf = vim.api.nvim_win_get_buf(archive_detail_win)
    delete_buffer_state(archive_detail_buffer_state, buf)
    vim.api.nvim_win_close(archive_detail_win, true)
    archive_detail_win = nil
    return true
  end
  archive_detail_win = nil
  return false
end

function M.open_archive_detail(change)
  M.close_archive_detail()
  local opts = config.get()
  local source_window = vim.api.nvim_get_current_win()
  local normalized = normalize_change(change)
  local parsed = nil
  if normalized.tasks_path ~= "" and util.is_file(normalized.tasks_path) then
    parsed, _ = tasks.parse_change(normalized)
  end
  local fallback = {
    sections = {},
    sections_needing_attention = {},
    counts = {
      todo = 0,
      wip = 0,
      skipped = 0,
      done = 0,
    },
    done = 0,
    total = 0,
  }
  local resolved = parsed or fallback
  local digest = artifacts.collect(normalized, resolved)
  local lines = {
    "OpenSpec Archive Detail",
    "Change " .. normalized.name,
    "Archive  " .. (normalized.archive_name or "(unknown)"),
    "Date     " .. (normalized.archive_date or "unknown"),
    "Source   " .. format_archive_source(normalized),
    "",
    string.format(
      "Task progress  DONE %d/%d  LEFT %d  TODO %d  WIP %d  SKIP %d",
      resolved.done,
      resolved.total,
      (resolved.counts.todo + resolved.counts.wip),
      resolved.counts.todo,
      resolved.counts.wip,
      resolved.counts.skipped
    ),
    string.format(
      "Artifacts  proposal:%s  design:%s  specs:%s  tasks:%s",
      artifact_flag(digest.proposal),
      artifact_flag(digest.design),
      artifact_flag(digest.specs_dir),
      artifact_flag(digest.tasks)
    ),
    "",
    "Artifact excerpts",
  }
  local width, height = summary_window_size(lines, opts)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  table.insert(lines, "  Proposal")
  table.insert(lines, "    " .. (digest.proposal and digest.proposal.summary ~= "" and digest.proposal.summary or "No proposal summary."))
  table.insert(lines, "  Design")
  table.insert(lines, "    " .. (digest.design and digest.design.summary ~= "" and digest.design.summary or "No design summary."))
  table.insert(lines, "  Tasks")
  table.insert(lines, "    " .. parse_task_excerpt(resolved))
  table.insert(lines, "  Spec deltas")
  if #digest.specs_names == 0 then
    table.insert(lines, "    No spec delta artifacts.")
  else
    for _, name in ipairs(digest.specs_names) do
      table.insert(lines, "    " .. name)
    end
  end
  table.insert(lines, "")
  table.insert(lines, archive_detail_key_hint())

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "openspec-archive-detail", { buf = buf })
  set_buffer_state(archive_detail_buffer_state, buf, {
    source_window = source_window,
    change = normalized,
  })

  archive_detail_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.ui.border,
    title = " OpenSpec Archive Detail ",
    title_pos = "center",
  })
  install_close_keymap(buf, function()
    M.close_archive_detail()
  end)
  vim.keymap.set("n", "p", function()
    open_artifact_from_change(normalized, "proposal", source_window, { close_archive_views = true })
  end, { buffer = buf, noremap = true, silent = true, nowait = true })
  vim.keymap.set("n", "d", function()
    open_artifact_from_change(normalized, "design", source_window, { close_archive_views = true })
  end, { buffer = buf, noremap = true, silent = true, nowait = true })
  vim.keymap.set("n", "t", function()
    open_artifact_from_change(normalized, "tasks", source_window, { close_archive_views = true })
  end, { buffer = buf, noremap = true, silent = true, nowait = true })
  vim.keymap.set("n", "s", function()
    open_artifact_from_change(normalized, "specs", source_window, { close_archive_views = true })
  end, { buffer = buf, noremap = true, silent = true, nowait = true })

  vim.api.nvim_set_option_value("wrap", true, { win = archive_detail_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = archive_detail_win })
  return archive_detail_win
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

function M._summary_lines(change, parsed)
  if parsed == nil then
    parsed = change
    change = {
      name = parsed.change_name,
      path = util.dirname(parsed.path),
      tasks_path = parsed.path,
    }
  end
  return summary_lines(change, parsed)
end

function M._summary_window_size(lines, opts)
  return summary_window_size(lines, opts)
end

function M._build_archive_search_lines(changes, query)
  return build_archive_search_lines(changes, query)
end

function M._archive_search_result_meta(buf, line_no)
  return archive_search_result_meta(buf, line_no)
end

function M._open_archive_search(changes, query)
  return M.open_archive_search(changes, query)
end

function M._close_archive_search()
  return M.close_archive_search()
end

function M._close_archive_views()
  return M.close_archive_views()
end

function M._open_archive_detail(change)
  return M.open_archive_detail(change)
end

function M._close_archive_detail()
  return M.close_archive_detail()
end

function M._open_artifact_from_change(change, kind, source_window, opts)
  return open_artifact_from_change(change, kind, source_window, opts)
end

function M._open_artifact_target(target, source_window, change_name)
  return open_artifact_target(target, source_window, change_name)
end

return M
