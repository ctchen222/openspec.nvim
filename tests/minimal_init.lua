vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.packpath:prepend(vim.fn.getcwd())

local state = vim.fn.tempname()
vim.fn.mkdir(state, "p")
vim.env.XDG_STATE_HOME = state
