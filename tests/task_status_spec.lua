dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false })

local tasks = require("openspec.tasks")

local line, err = tasks._replace_status_line("- [ ] 1.1 Todo", "done")
assert(not err, err)
assert(line == "- [x] 1.1 Todo", line)

line, err = tasks._replace_status_line("  - [x] 1.2 Done", "wip")
assert(not err, err)
assert(line == "  - [/] 1.2 Done", line)

line, err = tasks._replace_status_line("- [/] 1.3 Wip", "todo")
assert(not err, err)
assert(line == "- [ ] 1.3 Wip", line)

assert(tasks.task_text_from_line("- [ ] 1.5 Work <!-- openspec.nvim:task-id=tsk_known -->") == "1.5 Work")

line, err = tasks._replace_status_line("- [-] 1.4 Skipped", "skipped")
assert(not err, err)
assert(line == "- [-] 1.4 Skipped", line)

line, err = tasks._replace_status_line("not a task", "done")
assert(line == nil)
assert(err:find("checkbox task", 1, true), err)

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/update-task"
vim.fn.mkdir(change_path, "p")
local tasks_path = change_path .. "/tasks.md"
vim.fn.writefile({
  "# Tasks",
  "- [ ] 1.1 Todo",
  "- [x] 1.2 Done",
  "- [ ] 1.3 File task",
}, tasks_path)

vim.cmd("edit " .. vim.fn.fnameescape(tasks_path))
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("OpenSpecTaskStatus done")
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "- [x] 1.1 Todo")

vim.cmd("OpenSpecTaskStatus wip 3")
assert(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == "- [/] 1.2 Done")

local result
result, err = tasks.update_file_status(tasks_path, 4, "done", { expected_text = "1.3 File task" })
assert(not err, err)
assert(result.changed == true)
assert(vim.fn.readfile(tasks_path)[4] == "- [x] 1.3 File task")

result, err = tasks.update_file_status(tasks_path, 4, "todo", { expected_text = "changed" })
assert(result == nil)
assert(err:find("changed before status update", 1, true), err)

local task_buf = vim.api.nvim_get_current_buf()
vim.cmd("OpenSpecTaskStart 4")
assert(vim.api.nvim_buf_get_lines(task_buf, 3, 4, false)[1] == "- [/] 1.3 File task")

local workspace_buf = vim.api.nvim_get_current_buf()
local workspace_text = table.concat(vim.api.nvim_buf_get_lines(workspace_buf, 0, -1, false), "\n")
assert(vim.api.nvim_buf_get_name(workspace_buf):find("OpenSpec Workspace: update-task", 1, true))
assert(workspace_text:find("[WIP]", 1, true))
assert(workspace_text:find("1.3 File task", 1, true))

print("task status ok")
