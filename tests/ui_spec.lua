dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local parsed = require("openspec.tasks")._parse_lines({
  "# Plan",
  "## Phase A",
  "- [x] 1.1 Done",
  "- [ ] 1.2 Todo",
  "- [/] 1.3 Wip",
  "## Phase B",
  "- [ ] 2.1 Todo",
}, "/tmp/tasks.md", "demo-change")

local ui = require("openspec.ui")
local lines = ui._summary_lines(parsed)
local text = table.concat(lines, "\n")

assert(text:find("OpenSpec change", 1, true))
assert(text:find("demo-change", 1, true))
assert(text:find("25%% complete"))
assert(text:find("DONE 1/4", 1, true))
assert(text:find("LEFT 3", 1, true))
assert(text:find("NEXT ACTION", 1, true))
assert(text:find("[TODO] 1.2 Todo", 1, true))
assert(text:find("SECTIONS NEEDING ATTENTION", 1, true))
assert(not text:find("line %d+"))

vim.o.columns = 140
vim.o.lines = 40

local width, height = ui._summary_window_size(lines, require("openspec.config").get())
assert(width == 120, width)
assert(height >= 18, height)

ui.open_summary(parsed)
local win = vim.api.nvim_get_current_win()
assert(vim.api.nvim_win_get_width(win) == 120)
assert(vim.api.nvim_win_get_height(win) >= 18)
assert(ui.close_summary() == true)

local state = {
  recommendations = {
    { reason = "Continue implementation", command = "/opsx:apply demo-change" },
  },
  selected_task = parsed.next_task,
  cli = {
    status = {
      state = "ready",
    },
    validation = {
      ok = true,
      enabled = false,
    },
    enabled = false,
  },
  git = {
    branch = "feature/demo",
    worktree = "/tmp/demo",
    dirty = {},
  },
  findings = {
    { severity = "info", category = "artifact", message = "No blockers found.", path = "/tmp/tasks.md" },
  },
}
local workspace_win = ui.open_workspace({
  name = "demo-change",
  root = "/tmp/demo",
  tasks_path = "/tmp/tasks.md",
}, parsed, state)
assert(workspace_win == vim.api.nvim_get_current_win())
assert(vim.api.nvim_win_is_valid(workspace_win))
local workspace_buf = vim.api.nvim_win_get_buf(workspace_win)
assert(vim.api.nvim_get_option_value("buftype", { buf = workspace_buf }) == "nofile")
assert(vim.api.nvim_get_option_value("filetype", { buf = workspace_buf }) == "openspec-workspace")
assert(vim.api.nvim_buf_get_name(workspace_buf):find("OpenSpec Workspace: demo-change", 1, true))
local workspace_text = table.concat(vim.api.nvim_buf_get_lines(workspace_buf, 0, -1, false), "\n")
assert(workspace_text:find("OpenSpec Workspace", 1, true))
assert(workspace_text:find("local health") == nil)
assert(workspace_text:find("[Gg]ate") == nil)
assert(ui.close_workflow() == true)

print("ui ok")
