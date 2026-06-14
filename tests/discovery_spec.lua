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

vim.fn.mkdir(root .. "/openspec/changes/archive/2026-06-10-legacy", "p")
vim.fn.mkdir(root .. "/openspec/changes/archive/2026-06-12-alpha", "p")
vim.fn.mkdir(root .. "/openspec/changes/archive/2026-06-14-bugfix", "p")
vim.fn.mkdir(root .. "/openspec/changes/archive/old-without-date", "p")
vim.fn.mkdir(root .. "/openspec/changes/archive/2026-06-14-bugfix/specs", "p")
vim.fn.writefile({ "# Legacy tasks" }, root .. "/openspec/changes/archive/2026-06-10-legacy/tasks.md")
vim.fn.writefile({ "Proposal note" }, root .. "/openspec/changes/archive/2026-06-12-alpha/proposal.md")
vim.fn.writefile({ "Bugfix plan" }, root .. "/openspec/changes/archive/2026-06-14-bugfix/tasks.md")
vim.fn.writefile({ "design changes" }, root .. "/openspec/changes/archive/2026-06-14-bugfix/design.md")
vim.fn.mkdir(root .. "/openspec/changes/archive/2026-06-14-bugfix/specs/feature", "p")
vim.fn.writefile({ "# Spec", "details" }, root .. "/openspec/changes/archive/2026-06-14-bugfix/specs/feature/spec.md")

local archived_changes = discovery.scan_archived_changes(root)
assert(#archived_changes >= 4, #archived_changes)
assert(archived_changes[1].name == "bugfix", archived_changes[1].name)
assert(archived_changes[2].name == "alpha", archived_changes[2].name)
assert(archived_changes[3].name == "legacy", archived_changes[3].name)
assert(archived_changes[4].name == "old-without-date", archived_changes[4].name)
assert(archived_changes[1].archive_date == "2026-06-14")
assert(archived_changes[4].archive_date == nil)
assert(archived_changes[1].source_path == root .. "/openspec/changes/bugfix")

print("discovery ok")
