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

local tasks = require("openspec.tasks")
local health = require("openspec.health")
local cli = require("openspec.cli")

local original_has_executable = cli.has_executable
cli.has_executable = function()
  return false
end

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/health-demo"
vim.fn.mkdir(change_path .. "/specs/demo", "p")
vim.fn.writefile({ "## Why", "Health proposal" }, change_path .. "/proposal.md")
vim.fn.writefile({ "## Context", "Health design" }, change_path .. "/design.md")
vim.fn.writefile({ "## ADDED Requirements", "", "### Requirement: Health", "The plugin SHALL report local health.", "", "#### Scenario: Report health", "- **WHEN** requested", "- **THEN** a recommendation is present" }, change_path .. "/specs/demo/spec.md")
local tasks_path = change_path .. "/tasks.md"
vim.fn.writefile({
  "# Tasks",
  "- [ ] 1.1 Keep plugin healthy",
}, tasks_path)

local change = {
  name = "health-demo",
  path = change_path,
  root = root,
  tasks_path = tasks_path,
}

local parsed = tasks.parse_change(change)
local state = health.evaluate(change, parsed)

assert(state.cli and state.cli.enabled == false, "CLI disabled in this test context")
assert(#state.findings >= 1)
assert(state.findings[1].category == "openspec")
assert(state.recommendations[1].command:find("/opsx:apply", 1, true))
assert(state.selected_task and state.selected_task.text:find("Keep plugin healthy", 1, true))
assert(vim.tbl_isempty(state.findings) == false)

cli.has_executable = original_has_executable

print("health ok")
