dofile("tests/minimal_init.lua")

require("openspec").setup({
  mappings = {
    summary = "<leader>xs",
    html = "<leader>xh",
    workspace = "<leader>xw",
  },
})

assert(vim.fn.maparg("<leader>xs", "n") ~= "")
assert(vim.fn.maparg("<leader>xh", "n") ~= "")
assert(vim.fn.maparg("<leader>xw", "n") ~= "")
assert(vim.fn.maparg("<leader>ow", "n") == "")

print("setup custom ok")
