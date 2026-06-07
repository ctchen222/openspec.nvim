dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local root = vim.fn.tempname()
local change_path = root .. "/openspec/changes/add-demo"
vim.fn.mkdir(change_path .. "/specs/demo", "p")

vim.fn.writefile({
  "# Add demo",
  "",
  "## Summary",
  "",
  "Add a demo workflow for OpenSpec reporting.",
  "",
  "## Motivation",
  "",
  "Make the generated report easier to read.",
}, change_path .. "/proposal.md")

vim.fn.writefile({
  "# Design",
  "",
  "## Architecture",
  "",
  "Render a concise overview first.",
  "",
  "| Risk | Impact |",
  "|---|---|",
  "| Bad markdown | Hard to read |",
}, change_path .. "/design.md")

vim.fn.writefile({
  "# Demo Specification",
  "",
  "## ADDED Requirements",
  "",
  "### Requirement: Demo report",
  "",
  "The plugin SHALL render a change report.",
}, change_path .. "/specs/demo/spec.md")

local tasks_path = change_path .. "/tasks.md"
vim.fn.writefile({
  "# Tasks",
  "",
  "## 1. Build",
  "",
  "- [x] 1.1 Done task",
  "- [ ] 1.2 Todo task",
}, tasks_path)

local parsed = require("openspec.tasks").parse_change({
  name = "add-demo",
  path = change_path,
  tasks_path = tasks_path,
})

local html_module = require("openspec.html")
local lines = html_module._html_lines({
  name = "add-demo",
  path = change_path,
  tasks_path = tasks_path,
}, parsed)

local html = table.concat(lines, "\n")
local flattened = html_module._flatten_lines(lines)

assert(html:find("OpenSpec Change Report", 1, true))
assert(html:find("Add a demo workflow for OpenSpec reporting.", 1, true))
assert(html:find("Artifact Map", 1, true))
assert(html:find("Proposal", 1, true))
assert(html:find("Design", 1, true))
assert(html:find("Spec Delta", 1, true))
assert(html:find("Tasks", 1, true))
assert(html:find("Todo task", 1, true))
assert(html:find("markdown-body", 1, true))
assert(html:find("<h3>Summary</h3>", 1, true))
assert(html:find("<table>", 1, true))
assert(html:find("<th>Risk</th>", 1, true))
assert(html:find("<html lang=\"en\">", 1, true))
assert(html:find("id=\"theme-control\"", 1, true))
assert(html:find("for=\"theme-control\"", 1, true))
assert(html:find(".theme%-control:checked%+%.page"))
assert(html:find("icon%-sun"))
assert(html:find("icon%-moon"))
assert(not html:find("onclick=", 1, true))
assert(not html:find("<script", 1, true))
assert(not html:find("Light mode", 1, true))
assert(html:find("class=\"task-list\"", 1, true))
assert(html:find("class=\"task-row done\"", 1, true))
assert(html:find("data%-line=\"5\""))
assert(html:find("status-pill status-done", 1, true))
assert(html:find(".task%-section{padding:10px 24px 18px 34px}"))
assert(not html:find("class=\"task-line\"", 1, true))
assert(not html:find(">line ", 1, true))
assert(not html:find("text%-decoration:line%-through"))
assert(not html:find("<pre class=\"markdown\"", 1, true))
assert(not html:find("## Summary", 1, true))

for _, line in ipairs(flattened) do
  assert(not line:find("\n", 1, true))
  assert(not line:find("\0", 1, true))
end

local output_path = root .. "/report.html"
vim.fn.writefile(flattened, output_path)
local written = table.concat(vim.fn.readfile(output_path, "b"), "\n")
assert(not written:find("\0", 1, true))

print("html ok")
