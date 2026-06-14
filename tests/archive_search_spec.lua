dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local discovery = require("openspec.discovery")
local ui = require("openspec.ui")
local util = require("openspec.util")

local root = vim.fn.tempname()

local function write_file(path, lines)
  local dir = util.dirname(path)
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile(vim.split(lines, "\n", { plain = true }), path)
end

local function create_archive_change(root_dir, date, name, opts)
  opts = opts or {}
  local dir = root_dir .. "/openspec/changes/archive/" .. date .. "-" .. name
  vim.fn.mkdir(dir, "p")

  if opts.proposal then
    write_file(dir .. "/proposal.md", opts.proposal)
  end
  if opts.design then
    write_file(dir .. "/design.md", opts.design)
  end
  if opts.tasks then
    write_file(dir .. "/tasks.md", opts.tasks)
  end
  if opts.specs then
    for spec_name, body in pairs(opts.specs) do
      local spec_dir = dir .. "/specs/" .. spec_name
      vim.fn.mkdir(spec_dir, "p")
      write_file(spec_dir .. "/spec.md", body)
    end
  end

  return {
    name = name,
    path = dir,
    archive_name = date .. "-" .. name,
    archive_date = date,
    source_path = root_dir .. "/openspec/changes/" .. name,
  }
end

local changes = {
  create_archive_change(root, "2026-06-12", "alpha", {
    proposal = "Alpha proposal with query token TICKET-100.",
    design = "Design doc with TICKET-100.",
    tasks = "- [x] TICKET-100 completed\n- [ ] followup",
    specs = {
      overview = "## Proposal\nTICKET-100 in spec",
      backend = "## MODIFIED Requirements\nTICKET-100 details",
    },
  }),
  create_archive_change(root, "2026-06-10", "beta", {
    proposal = "Beta proposal text.",
    design = "Beta design text.",
    tasks = "- [ ] beta task",
    specs = {
      first = "## MODIFIED\nbeta spec",
    },
  }),
  create_archive_change(root, "2026-06-11", "multi", {
    proposal = "Multi proposal.",
    design = "Multi design.",
    tasks = string.rep("- [ ] alpha\n", 6),
    specs = {
      one = "## MODIFIED\nno match",
      two = "## MODIFIED\nno match",
    },
  }),
}

local discovered = discovery.scan_archived_changes(root)
assert(#discovered >= 3)
assert(discovered[1].name == "alpha")

local lines, line_metadata = ui._build_archive_search_lines(discovered, "")
local text = table.concat(lines, "\n")
assert(text:find("OpenSpec Archive Search", 1, true))
assert(text:find("Keys: <Enter> detail  p proposal  d design  t tasks  s spec  q close", 1, true))
assert(text:find("Archive dir", 1, true))
assert(text:find("2026-06-12", 1, true))

local metadata_found = false
for _, meta in pairs(line_metadata or {}) do
  if meta and meta.kind == "detail" then
    metadata_found = true
    break
  end
end
assert(metadata_found)

local query_lines = ui._build_archive_search_lines(discovered, "TICKET-100")
assert(query_lines[1]:find("OpenSpec Archive Search", 1, true))
assert(table.concat(query_lines, "\n"):find("Proposal matches", 1, true))
assert(table.concat(query_lines, "\n"):find("Design matches", 1, true))
assert(table.concat(query_lines, "\n"):find("Specs matches", 1, true))

local _, query_metadata = ui._build_archive_search_lines(discovered, "TICKET-100")
local artifact_meta = false
for _, meta in pairs(query_metadata or {}) do
  if meta.kind == "artifact" and meta.target then
    artifact_meta = true
    break
  end
end
assert(artifact_meta)

local no_match_lines = ui._build_archive_search_lines(discovered, "NO_MATCH_TOKEN")
assert(table.concat(no_match_lines, "\n"):find("No matches. Try a shorter query or run :OpenSpecArchiveSearch without a query", 1, true))

local original_cwd = vim.fn.getcwd()
vim.cmd("cd " .. vim.fn.fnameescape(root))
openspec.archive_search({ fargs = { "TICKET-100" } })
local first_archive_search_win = vim.api.nvim_get_current_win()
assert(vim.api.nvim_win_is_valid(first_archive_search_win))
openspec.archive_search({ fargs = { "TICKET-100" } })
assert(not vim.api.nvim_win_is_valid(first_archive_search_win))

local lifecycle_search_win = ui._open_archive_search(discovered, "TICKET-100")
local lifecycle_search_buf = vim.api.nvim_win_get_buf(lifecycle_search_win)
ui._open_artifact_from_change(discovered[1], "proposal", nil, { close_archive_views = true })
assert(not vim.api.nvim_win_is_valid(lifecycle_search_win))
vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

local empty_root = vim.fn.tempname()
vim.fn.mkdir(empty_root .. "/openspec/changes", "p")
local empty_lines = ui._build_archive_search_lines(discovery.scan_archived_changes(empty_root), "")
assert(table.concat(empty_lines, "\n"):find("No archived changes found.", 1, true))
assert(table.concat(empty_lines, "\n"):find("openspec/changes/archive", 1, true))

local capped_root = vim.fn.tempname()
for idx = 1, 27 do
  local day = string.format("%02d", idx)
  create_archive_change(capped_root, "2026-01-" .. day, "case-" .. idx, {
    tasks = string.rep("TICKET-100\n", 7),
    proposal = "capped proposal TICKET-100",
  })
end
local capped_changes = discovery.scan_archived_changes(capped_root)
assert(#capped_changes >= 27)
local capped_lines = ui._build_archive_search_lines(capped_changes, "TICKET-100")
assert(table.concat(capped_lines, "\n"):find("Found 27 archived changes", 1, true))
assert(table.concat(capped_lines, "\n"):find("Showing 25", 1, true))
assert(table.concat(capped_lines, "\n"):find("... more matches for this change", 1, true))

local detail_win = ui._open_archive_detail(discovered[1])
assert(detail_win == vim.api.nvim_get_current_win())
local detail_buf = vim.api.nvim_win_get_buf(detail_win)
local detail_text = table.concat(vim.api.nvim_buf_get_lines(detail_buf, 0, -1, false), "\n")
assert(vim.api.nvim_get_option_value("modifiable", { buf = detail_buf }) == false)
assert(vim.api.nvim_get_option_value("filetype", { buf = detail_buf }) == "openspec-archive-detail")
assert(detail_text:find("OpenSpec Archive Detail", 1, true))
assert(detail_text:find("Task progress", 1, true))
assert(detail_text:find("Artifacts", 1, true))
assert(detail_text:find("Artifact excerpts", 1, true))
ui._open_artifact_from_change(discovered[1], "tasks", nil, { close_archive_views = true })
assert(not vim.api.nvim_win_is_valid(detail_win))
ui._close_archive_detail()

local search_win = ui._open_archive_search(discovered, "TICKET-100")
assert(search_win == vim.api.nvim_get_current_win())
local search_buf = vim.api.nvim_win_get_buf(search_win)
local maps = vim.api.nvim_buf_get_keymap(search_buf, "n")
local has_enter = false
local has_q = false
for _, map in ipairs(maps) do
  if map.lhs == "<CR>" then
    has_enter = true
  end
  if map.lhs == "q" then
    has_q = true
  end
end
assert(has_enter)
assert(has_q)
ui._close_archive_search()

local active_root = root .. "/active-summary"
vim.fn.mkdir(active_root, "p")
vim.fn.writefile({ "# Plan", "- [ ] 1.1 do one", "- [ ] 1.2 do two" }, active_root .. "/tasks.md")
vim.fn.writefile({ "Active proposal" }, active_root .. "/proposal.md")
vim.fn.writefile({ "Active design" }, active_root .. "/design.md")
vim.fn.mkdir(active_root .. "/specs/first", "p")
vim.fn.mkdir(active_root .. "/specs/second", "p")
vim.fn.writefile({ "# MODIFIED", "one" }, active_root .. "/specs/first/spec.md")
vim.fn.writefile({ "# MODIFIED", "two" }, active_root .. "/specs/second/spec.md")

local summary_change = {
  name = "active-summary",
  path = active_root,
  root = root,
  tasks_path = active_root .. "/tasks.md",
}
local summary_parsed = require("openspec.tasks")._parse_lines(vim.fn.readfile(summary_change.tasks_path), summary_change.tasks_path, summary_change.name)

ui.open_summary(summary_change, summary_parsed)
local summary_buf = vim.api.nvim_get_current_buf()
local summary_maps = vim.api.nvim_buf_get_keymap(summary_buf, "n")
local summary_has_p = false
local summary_has_s = false
for _, map in ipairs(summary_maps) do
  if map.lhs == "p" then
    summary_has_p = true
  end
  if map.lhs == "s" then
    summary_has_s = true
  end
end
assert(summary_has_p)
assert(summary_has_s)

local original_ui_select = vim.ui.select
local select_called = false
vim.ui.select = function(...)
  select_called = true
  local args = { ... }
  if type(args[3]) == "function" then
    args[3](args[1][1])
  end
end
ui._open_artifact_from_change(summary_change, "specs")
vim.ui.select = original_ui_select
assert(select_called)

ui.close_summary()

print("archive search ok")
