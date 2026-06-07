local M = {}

local uv = vim.uv or vim.loop

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "OpenSpec" })
end

function M.normalize_path(path)
  if not path or path == "" then
    return ""
  end

  local absolute = vim.fn.fnamemodify(path, ":p")
  if #absolute > 1 then
    absolute = absolute:gsub("/$", "")
  end
  return absolute
end

function M.join_path(...)
  return table.concat({ ... }, "/")
end

function M.stat_type(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type or nil
end

function M.is_dir(path)
  return M.stat_type(path) == "directory"
end

function M.is_file(path)
  return M.stat_type(path) == "file"
end

function M.basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

function M.dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

function M.percent(done, total)
  if total == 0 then
    return 0
  end
  return math.floor((done / total) * 100 + 0.5)
end

function M.escape_html(value)
  return tostring(value)
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
    :gsub("'", "&#39;")
end

return M
