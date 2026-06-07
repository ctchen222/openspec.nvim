dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local root = vim.fn.tempname()
local change_dir = root .. "/openspec/changes/add-dashboard"
vim.fn.mkdir(change_dir, "p")
vim.fn.writefile({ "# Tasks", "- [ ] 1.1 Do the work" }, change_dir .. "/tasks.md")
vim.fn.mkdir(root .. "/openspec/changes/archive", "p")

local discovery = require("openspec.discovery")
local found_root = discovery.find_root(change_dir .. "/tasks.md")
assert(found_root == root, string.format("expected %s, got %s", root, found_root))

local changes = discovery.scan_active_changes(root)
assert(#changes == 1, #changes)
assert(changes[1].name == "add-dashboard", changes[1].name)
assert(changes[1].tasks_path == change_dir .. "/tasks.md", changes[1].tasks_path)

print("discovery ok")
