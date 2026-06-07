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
assert(text:find("Model Routing", 1, true))
assert(text:find("Planning/spec", 1, true))
assert(text:find("Implementation", 1, true))
assert(text:find("does not switch models", 1, true))

openspec.setup({
  commands = false,
  keymaps = false,
  health = {
    validation = {
      enabled = false,
    },
  },
  context = {
    model_routing = {
      profiles = {
        {
          name = "Spec planning",
          model = "gpt-5.5",
          effort = "xhigh",
          command = "/model gpt-5.5 xhigh",
          use_for = "spec decisions before implementation",
        },
        {
          name = "Task implementation",
          model = "gpt-5.4",
          effort = "high",
          command = "/model gpt-5.4 high",
          use_for = "code edits and focused checks",
        },
      },
      switch_rules = {
        "Switch after spec approval.",
      },
    },
  },
})

local custom_text = table.concat(context.lines(change, parsed, health.evaluate(change, parsed, { task = parsed.next_task })), "\n")
assert(custom_text:find("Spec planning", 1, true))
assert(custom_text:find("gpt-5.5", 1, true))
assert(custom_text:find("/model gpt-5.4 high", 1, true))
assert(custom_text:find("Switch after spec approval.", 1, true))
assert(not custom_text:find("Verification/audit", 1, true))

openspec.setup({
  commands = false,
  keymaps = false,
  health = {
    validation = {
      enabled = false,
    },
  },
  context = {
    model_routing = {
      enabled = false,
    },
  },
})

local disabled_text = table.concat(context.lines(change, parsed, health.evaluate(change, parsed, { task = parsed.next_task })), "\n")
assert(not disabled_text:find("Model Routing", 1, true))

print("context ok")
