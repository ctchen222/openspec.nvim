local M = {}

local defaults = {
  commands = true,
  keymaps = true,
  mappings = {
    summary = "<leader>os",
    html = "<leader>oh",
    workspace = "<leader>ow",
  },
  openspec = {
    executable = "openspec",
    changes_dir = "openspec/changes",
    archive_dir = "archive",
    tasks_file = "tasks.md",
  },
  tasks = {
    include_skipped_in_total = false,
    statuses = {
      todo = { " " },
      done = { "x", "X" },
      wip = { "/", "~", ">" },
      skipped = { "-" },
    },
  },
  ui = {
    border = "rounded",
    max_width = 120,
  },
  context = {
    model_routing = {
      enabled = true,
      profiles = {
        {
          name = "Planning/spec",
          model = "strongest planning model",
          effort = "highest available",
          use_for = "proposal, design, spec delta, task shaping, and scope decisions",
        },
        {
          name = "Implementation",
          model = "cost-aware implementation model",
          effort = "high",
          use_for = "code edits, focused tests, documentation updates, and small refactors",
        },
        {
          name = "Verification/audit",
          model = "implementation model unless ambiguity requires planning",
          effort = "high",
          use_for = "failed checks, review notes, audit evidence, and unclear acceptance criteria",
        },
      },
      switch_rules = {
        "Start with the planning/spec profile only while shaping proposal, design, spec, or tasks.",
        "Switch to the implementation profile before editing code, tests, or docs.",
        "Switch back to planning/spec only when scope, requirements, or acceptance criteria are unclear.",
        "Use verification/audit for failed checks, review, and completion evidence.",
      },
    },
  },
  health = {
    validation = {
      enabled = true,
    },
  },
}

local options = vim.deepcopy(defaults)

local function apply_model_routing_list_overrides(merged, opts)
  local routing = opts and opts.context and opts.context.model_routing
  if not routing then
    return
  end
  if routing.profiles ~= nil then
    merged.context.model_routing.profiles = vim.deepcopy(routing.profiles)
  end
  if routing.switch_rules ~= nil then
    merged.context.model_routing.switch_rules = vim.deepcopy(routing.switch_rules)
  end
end

function M.setup(opts)
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  apply_model_routing_list_overrides(merged, opts)
  options = merged
end

function M.get()
  return options
end

function M.status_lookup()
  local lookup = {}
  for status, chars in pairs(options.tasks.statuses) do
    for _, char in ipairs(chars) do
      lookup[char] = status
    end
  end
  return lookup
end

return M
