local config = require("openspec.config")
local util = require("openspec.util")

local M = {}

function M.find_root(start_path)
  local opts = config.get()
  local path = util.normalize_path(start_path ~= "" and start_path or vim.fn.getcwd())
  local dir = util.is_dir(path) and path or util.dirname(path)

  while dir and dir ~= "" do
    if util.is_dir(util.join_path(dir, opts.openspec.changes_dir)) then
      return dir
    end

    local parent = util.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

function M.scan_active_changes(root)
  local opts = config.get()
  local changes_dir = util.join_path(root, opts.openspec.changes_dir)
  local paths = vim.fn.glob(util.join_path(changes_dir, "*"), false, true)
  local changes = {}

  for _, path in ipairs(paths) do
    local name = util.basename(path)
    local tasks_path = util.join_path(path, opts.openspec.tasks_file)

    if name ~= opts.openspec.archive_dir and util.is_dir(path) and util.is_file(tasks_path) then
      table.insert(changes, {
        name = name,
        path = util.normalize_path(path),
        root = util.normalize_path(root),
        tasks_path = util.normalize_path(tasks_path),
      })
    end
  end

  table.sort(changes, function(a, b)
    return a.name < b.name
  end)

  return changes
end

function M.change_from_current_buffer(root)
  local opts = config.get()
  local current = util.normalize_path(vim.api.nvim_buf_get_name(0))
  if current == "" then
    return nil
  end

  local changes_dir = util.normalize_path(util.join_path(root, opts.openspec.changes_dir))
  local prefix = changes_dir .. "/"
  if current:sub(1, #prefix) ~= prefix then
    return nil
  end

  local relative = current:sub(#prefix + 1)
  local change_name = relative:match("^([^/]+)")
  if not change_name or change_name == opts.openspec.archive_dir then
    return nil
  end

  local change_path = util.join_path(changes_dir, change_name)
  local tasks_path = util.join_path(change_path, opts.openspec.tasks_file)
  if not util.is_file(tasks_path) then
    return nil
  end

  return {
    name = change_name,
    path = util.normalize_path(change_path),
    root = util.normalize_path(root),
    tasks_path = util.normalize_path(tasks_path),
  }
end

return M
