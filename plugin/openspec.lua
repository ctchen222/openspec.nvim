if vim.g.loaded_openspec_nvim then
  return
end

vim.g.loaded_openspec_nvim = true

vim.api.nvim_create_user_command("OpenSpecSetup", function()
  require("openspec").setup()
end, {
  desc = "Register openspec.nvim commands and default keymaps",
})
