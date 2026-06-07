dofile("tests/minimal_init.lua")

require("openspec").setup({ keymaps = false, commands = false })

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/artifact-demo"
vim.fn.mkdir(change_path .. "/specs/demo", "p")

vim.fn.writefile({
  "# Proposal",
  "",
  "## Summary",
  "",
  "Build artifact digest for the workspace cockpit.",
  "",
  "## Details",
  "",
  "This sentence should not be needed.",
}, change_path .. "/proposal.md")
vim.fn.writefile({ "# Tasks", "", "- [ ] 1.1 Build digest" }, change_path .. "/tasks.md")
vim.fn.writefile({ "# Demo Spec" }, change_path .. "/specs/demo/spec.md")

local artifacts = require("openspec.artifacts").collect({
  name = "artifact-demo",
  path = change_path,
  tasks_path = change_path .. "/tasks.md",
}, {
  sections = {
    { name = "Low", done = 0, total = 1, todo = 0, wip = 1, skipped = 0 },
    { name = "High", done = 0, total = 2, todo = 2, wip = 0, skipped = 0 },
    { name = "Done", done = 1, total = 1, todo = 0, wip = 0, skipped = 0 },
  },
})

assert(artifacts.proposal.present == true)
assert(artifacts.proposal.relative_path == "proposal.md")
assert(artifacts.proposal.summary == "Build artifact digest for the workspace cockpit.")
assert(artifacts.design.present == false)
assert(artifacts.design.relative_path == "design.md")
assert(artifacts.tasks.present == true)
assert(artifacts.tasks.relative_path == "tasks.md")
assert(#artifacts.specs == 1)
assert(artifacts.specs_count == 1)
assert(#artifacts.specs_names == 1)
assert(artifacts.specs_names[1] == "demo")
assert(artifacts.specs[1].label == "demo")
assert(artifacts.specs[1].relative_path == "specs/demo/spec.md")
assert(artifacts.specs_dir.present == true)
assert(#artifacts.sections_needing_attention == 2)
assert(artifacts.sections_needing_attention[1].name == "High")
assert(artifacts.sections_needing_attention[2].name == "Low")

vim.fn.delete(change_path .. "/proposal.md")
vim.fn.writefile({ "# Proposal", "", "Fallback excerpt line.", "", "Second line." }, change_path .. "/proposal.md")
local fallback = require("openspec.artifacts").collect({
  name = "artifact-demo",
  path = change_path,
  tasks_path = change_path .. "/tasks.md",
})
assert(fallback.proposal.summary == "Fallback excerpt line. Second line.")

print("artifacts ok")
