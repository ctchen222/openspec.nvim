local M = {}

local defaults = {
  commands = true,
  keymaps = true,
  mappings = {
    summary = "<leader>os",
    html = "<leader>oh",
    workspace = "<leader>ow",
    archive = "<leader>oa",
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
  health = {
    validation = {
      enabled = true,
    },
  },
  implement = {
    default_profile = "implementation",
    goal = "off",
    profiles = {
      implementation = {
        model = "gpt-5.4",
        effort = "high",
        layout = "auto",
      },
    },
    providers = {},
    layouts = {
      non_tmux = "nvim-right",
    },
    tmux = {
      min_pane_width_for_right = 140,
    },
    external = {
      command_template = nil,
    },
  },
}

local options = vim.deepcopy(defaults)

function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
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
