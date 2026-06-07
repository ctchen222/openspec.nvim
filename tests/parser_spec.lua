dofile("tests/minimal_init.lua")

local openspec = require("openspec")
openspec.setup({ keymaps = false, commands = false })

local parsed = require("openspec.tasks")._parse_lines({
  "# Plan",
  "- [x] 1.1 Done",
  "- [ ] 1.2 Todo <!-- openspec.nvim:task-id=tsk_existing123 -->",
  "- [/] 1.3 Wip",
  "- [-] 1.4 Skip",
  "## Phase 2",
  "- [X] 2.1 Done again",
}, "/tmp/tasks.md", "demo")

assert(parsed.done == 2, parsed.done)
assert(parsed.total == 4, parsed.total)
assert(parsed.percent == 50, parsed.percent)
assert(parsed.counts.todo == 1, parsed.counts.todo)
assert(parsed.counts.wip == 1, parsed.counts.wip)
assert(parsed.counts.skipped == 1, parsed.counts.skipped)
assert(parsed.next_task.text == "1.2 Todo", parsed.next_task and parsed.next_task.text)
assert(parsed.next_task.text == "1.2 Todo")

print("parser ok")
