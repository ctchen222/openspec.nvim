dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({
  commands = false,
  keymaps = false,
  health = {
    validation = {
      enabled = false,
    },
  },
})

local context = require("openspec.context")
local health = require("openspec.health")
local implement = require("openspec.implement")

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/implement-demo"
vim.fn.mkdir(change_path .. "/specs/demo", "p")
vim.fn.writefile({ "## Why", "Implement proposal" }, change_path .. "/proposal.md")
vim.fn.writefile({ "## Context", "Implement design" }, change_path .. "/design.md")
vim.fn.writefile({ "## ADDED Requirements", "", "### Requirement: Implement", "The plugin SHALL build implement context.", "", "#### Scenario: Build implement context", "- **WHEN** requested", "- **THEN** context is built" }, change_path .. "/specs/demo/spec.md")

local tasks_path = change_path .. "/tasks.md"
vim.fn.writefile({
  "# Tasks",
  "- [ ] 1.1 First task",
  "- [ ] 1.2 Second task",
}, tasks_path)
vim.fn.writefile({ "notes" }, root .. "/notes.md")

local original_context_lines = context.lines
local original_evaluate = health.evaluate
local original_start = implement.start
local last_evaluate = nil
local last_start = nil

context.lines = function(_change, _parsed, state)
  return { state.selected_task and state.selected_task.text or "whole-change" }
end

health.evaluate = function(_change, _parsed, opts)
  last_evaluate = opts
  return {
    selected_task = opts.task,
    findings = {},
    git = { dirty = {}, branch = "feature/implement-demo" },
    cli = { validation = { enabled = false, ok = true } },
    recommendations = {},
  }
end

implement.start = function(change_name, task, lines, fargs)
  last_start = {
    change_name = change_name,
    task = task,
    lines = lines,
    fargs = fargs,
  }
end

local function run_implement(path, line)
  last_evaluate = nil
  last_start = nil
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  if line then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  end
  openspec.implement({ fargs = { "codex" } })
  assert(last_evaluate ~= nil)
  assert(last_start ~= nil)
  return last_evaluate, last_start
end

vim.fn.chdir(root)

local selected_opts, selected_start = run_implement(tasks_path, 2)
assert(selected_opts.fallback_to_next_task == false)
assert(selected_start.change_name == "implement-demo")
assert(selected_start.task ~= nil)
assert(selected_start.task.text == "1.1 First task")
assert(selected_start.lines[1] == "1.1 First task")
assert(selected_start.fargs[1] == "codex")

local header_opts, header_start = run_implement(tasks_path, 1)
assert(header_opts.fallback_to_next_task == false)
assert(header_start.task == nil)
assert(header_start.lines[1] == "whole-change")

local off_task_opts, off_task_start = run_implement(root .. "/notes.md", 1)
assert(off_task_opts.fallback_to_next_task == false)
assert(off_task_start.task == nil)
assert(off_task_start.lines[1] == "whole-change")

context.lines = original_context_lines
health.evaluate = original_evaluate
implement.start = original_start

print("init implement ok")
