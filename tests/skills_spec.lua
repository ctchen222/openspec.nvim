dofile("tests/minimal_init.lua")

-- legacy skill-only command surface should be removed in this direction
assert(vim.fn.isdirectory(".codex/skills/openspec-agent-loop") == 0)
assert(vim.fn.isdirectory(".claude/skills/openspec-agent-loop") == 0)

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = true })
local commands = vim.api.nvim_get_commands({})

assert(commands.OpenSpecWorkspace ~= nil)
assert(commands.OpenSpecContext ~= nil)
assert(commands.OpenSpecImplement ~= nil)
assert(commands.OpenSpecTaskStart ~= nil)
assert(commands.OpenSpecCurrent ~= nil)
assert(commands.OpenSpecTaskStatus ~= nil)
assert(commands.OpenSpecAudit == nil)
assert(commands.OpenSpecPreflight == nil)

print("skills ok")
