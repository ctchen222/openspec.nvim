local config = require("openspec.config")

local M = {}

local function shell_arg(value)
  return vim.fn.shellescape(value)
end

local function command_exec(root, args)
  local exe = config.get().openspec.executable
  if not exe or exe == "" then
    exe = "openspec"
  end

  if vim.fn.executable(exe) ~= 1 then
    return nil, "openspec executable not found"
  end

  local root_arg = shell_arg(root or vim.fn.getcwd())
  local parts = { shell_arg(exe) }
  for _, value in ipairs(args) do
    table.insert(parts, shell_arg(value))
  end

  local command = table.concat(parts, " ")
  local output = vim.fn.systemlist("cd " .. root_arg .. " && " .. command)
  local code = vim.v.shell_error
  if code ~= 0 then
    return nil, table.concat(output, "\n")
  end
  return output, nil
end

local function decode_json(lines)
  local text = table.concat(lines, "\n")
  local ok, decoded = pcall(vim.json.decode, text)
  if ok then
    return decoded, nil
  end

  local start = text:find("{", 1, true)
  if start then
    local snippet = text:sub(start)
    ok, decoded = pcall(vim.json.decode, snippet)
    if ok then
      return decoded, nil
    end
  end

  local array_start = text:find("[", 1, true)
  if array_start then
    local snippet = text:sub(array_start)
    ok, decoded = pcall(vim.json.decode, snippet)
    if ok then
      return decoded, nil
    end
  end

  return nil, "unable to parse openspec json output"
end

local function run_json(root, args)
  table.insert(args, "--json")
  local lines, err = command_exec(root, args)
  if not lines then
    return nil, err
  end
  local payload, parse_error = decode_json(lines)
  if not payload then
    return nil, parse_error
  end
  return payload, nil
end

function M.has_executable()
  return vim.fn.executable(config.get().openspec.executable or "openspec") == 1
end

function M.list_changes(root)
  return run_json(root, { "list" })
end

function M.status(change_name, root)
  local safe_name = change_name or ""
  if safe_name == "" then
    return nil, "change name is required"
  end
  return run_json(root, { "status", "--change", safe_name })
end

function M.instructions_apply(change_name, root)
  local safe_name = change_name or ""
  if safe_name == "" then
    return nil, "change name is required"
  end
  return run_json(root, { "instructions", "apply", "--change", safe_name })
end

function M.validate(opts)
  opts = opts or {}
  local args = { "validate", "--all", "--strict" }
  if opts.change then
    table.insert(args, 2, "--change")
    table.insert(args, 3, opts.change)
  end
  return run_json(opts.root, args)
end

function M._command_exec_for_tests(root, args)
  return command_exec(root, args)
end

function M._decode_json(lines)
  return decode_json(lines)
end

return M
