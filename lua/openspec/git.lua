local M = {}

local function shell_arg(value)
  return vim.fn.shellescape(value)
end

local function system_lines(root, args)
  if vim.fn.executable("git") ~= 1 then
    return nil, "git executable not found"
  end

  local command = { "git", "-C", shell_arg(root) }
  for _, arg in ipairs(args) do
    table.insert(command, arg)
  end

  local output = vim.fn.systemlist(table.concat(command, " "))
  local code = vim.v.shell_error
  if code ~= 0 then
    return nil, table.concat(output, "\n")
  end
  return output, nil
end

function M.info(root)
  local info = {
    branch = nil,
    dirty = {},
    root = root,
    worktree = nil,
  }

  local branch = system_lines(root, { "branch", "--show-current" })
  if branch and branch[1] and branch[1] ~= "" then
    info.branch = branch[1]
  end

  local worktree = system_lines(root, { "rev-parse", "--show-toplevel" })
  if worktree and worktree[1] and worktree[1] ~= "" then
    info.worktree = worktree[1]
  end

  local dirty = system_lines(root, { "status", "--short" })
  if dirty then
    info.dirty = dirty
  end

  return info
end

return M
