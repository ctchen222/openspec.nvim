dofile("tests/minimal_init.lua")

require("openspec").setup({ keymaps = false })

local commands = vim.api.nvim_get_commands({})
assert(commands.OpenSpecWorkspace ~= nil)
assert(vim.fn.maparg("<leader>os", "n") == "")
assert(vim.fn.maparg("<leader>oh", "n") == "")
assert(vim.fn.maparg("<leader>ow", "n") == "")

print("setup no keymaps ok")
