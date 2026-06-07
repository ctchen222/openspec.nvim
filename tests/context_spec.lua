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
local tasks = require("openspec.tasks")
local health = require("openspec.health")

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/context-demo"
vim.fn.mkdir(change_path .. "/specs/demo", "p")
vim.fn.writefile({ "## Why", "Context proposal" }, change_path .. "/proposal.md")
vim.fn.writefile({ "## Context", "Context design" }, change_path .. "/design.md")
vim.fn.writefile({ "## ADDED Requirements", "", "### Requirement: Context", "The plugin SHALL build context.", "", "#### Scenario: Build context", "- **WHEN** requested", "- **THEN** context is built" }, change_path .. "/specs/demo/spec.md")
local tasks_path = change_path .. "/tasks.md"
vim.fn.writefile({
  "# Tasks",
  "- [ ] 1.1 Build context <!-- openspec.nvim:task-id=tsk_context -->",
}, tasks_path)

local change = {
  name = "context-demo",
  path = change_path,
  root = root,
  tasks_path = tasks_path,
}
local parsed = tasks.parse_change(change)
local state = health.evaluate(change, parsed, { task = parsed.next_task })
local lines = context.lines(change, parsed, state)
local text = table.concat(lines, "\n")

assert(text:find("# OpenSpec Upstream Context", 1, true))
assert(text:find("tsk_context", 1, true))
assert(text:find("Do not treat this buffer", 1, true))
assert(text:find("Context proposal", 1, true))
assert(text:find("Spec Delta", 1, true))
assert(text:find("Allowed Scope", 1, true))
assert(text:find("Forbidden Scope", 1, true))
assert(text:find("Verification Commands", 1, true))
assert(text:find("Stop Conditions", 1, true))
assert(text:find("Validation:", 1, true))
assert(text:find("Dirty entries:", 1, true))

print("context ok")
