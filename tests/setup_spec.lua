dofile("tests/minimal_init.lua")

require("openspec").setup({
  mappings = {
    summary = "<leader>xs",
    html = "<leader>xh",
  },
})

local commands = vim.api.nvim_get_commands({})

assert(commands.OpenSpecTasksSummary ~= nil)
assert(commands.OpenSpecTasks == nil)
assert(commands.OpenSpecTasksAll == nil)
assert(commands.OpenSpecTasksNext == nil)
assert(commands.OpenSpecTasksHtml ~= nil)
assert(commands.OpenSpecWorkspace ~= nil)
assert(commands.OpenSpecTaskStart ~= nil)
assert(commands.OpenSpecContext ~= nil)
assert(commands.OpenSpecImplement ~= nil)
assert(commands.OpenSpecArchiveSearch ~= nil)
assert(commands.OpenSpecCurrent ~= nil)
assert(commands.OpenSpecTaskStatus ~= nil)
assert(commands.OpenSpecAudit == nil)
assert(vim.fn.maparg("<leader>xs", "n") ~= "")
assert(vim.fn.maparg("<leader>xh", "n") ~= "")
assert(vim.fn.maparg("<leader>ow", "n") ~= "")
assert(vim.fn.maparg("<leader>xt", "n") == "")
assert(vim.fn.maparg("<leader>xa", "n") == "")
assert(vim.fn.maparg("<leader>xn", "n") == "")

print("setup ok")
