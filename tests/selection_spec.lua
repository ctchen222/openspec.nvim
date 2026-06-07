dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/only-change"
vim.fn.mkdir(change_path, "p")
vim.fn.writefile({
  "# Plan",
  "- [ ] 1.1 Pick this change",
}, change_path .. "/tasks.md")

vim.cmd("edit " .. vim.fn.fnameescape(change_path .. "/tasks.md"))

local select_calls = 0
local selected_items = nil
local old_select = vim.ui.select
vim.ui.select = function(items, opts, callback)
  select_calls = select_calls + 1
  selected_items = items
  assert(opts.prompt == "OpenSpec summary change")
  callback(items[1])
end

openspec.summary()

vim.ui.select = old_select

assert(select_calls == 1, select_calls)
assert(#selected_items == 1, #selected_items)
assert(selected_items[1].name == "only-change")

local buf = vim.api.nvim_get_current_buf()
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
assert(text:find("OpenSpec Summary", 1, true))
assert(text:find("only-change", 1, true))

require("openspec.ui").close_summary()

print("selection ok")
