local util = require("openspec.util")

local M = {}

local function change_path(change)
  if change.path and change.path ~= "" then
    return change.path
  end
  if change.tasks_path and change.tasks_path ~= "" then
    return util.dirname(change.tasks_path)
  end
  return vim.fn.getcwd()
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function read_file(path)
  if not path or not util.is_file(path) then
    return nil
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end

  return table.concat(lines, "\n")
end

local function section_content(markdown, wanted)
  if not markdown then
    return nil
  end

  local wanted_lower = wanted:lower()
  local lines = vim.split(markdown, "\n", { plain = true })
  local capture = false
  local capture_level = nil
  local collected = {}

  for _, line in ipairs(lines) do
    local marks, title = line:match("^(#+)%s+(.+)$")
    if marks and title then
      local level = #marks
      local clean_title = title:gsub("%s+#*$", ""):lower()

      if capture and level <= capture_level then
        break
      end

      if clean_title == wanted_lower then
        capture = true
        capture_level = level
      elseif capture then
        table.insert(collected, line)
      end
    elseif capture then
      table.insert(collected, line)
    end
  end

  local content = trim(table.concat(collected, "\n"))
  if content == "" then
    return nil
  end
  return content
end

local function excerpt(markdown, opts)
  opts = opts or {}
  local text = markdown or ""
  text = text:gsub("`", "")
  local parts = {}

  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    if not line:match("^%s*#+%s+") then
      line = line:gsub("^%s*[-*+]%s*", "")
      line = trim(line)
      if line ~= "" then
        table.insert(parts, line)
      end
      if #parts >= (opts.max_lines or 2) then
        break
      end
    end
  end

  local result = table.concat(parts, " ")
  local limit = opts.limit or 260
  if #result > limit then
    result = result:sub(1, limit - 3) .. "..."
  end
  return result
end

local function proposal_summary(content)
  return excerpt(section_content(content, "Summary") or content)
end

local function relative_path(change, path)
  if not path then
    return ""
  end

  local normalized = util.normalize_path(path)
  local root = util.normalize_path(change_path(change))
  local prefix = root .. "/"
  if normalized == root then
    return "."
  end
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return normalized
end

local function artifact(change, label, path)
  local normalized = util.normalize_path(path)
  return {
    content = read_file(normalized),
    label = label,
    path = normalized,
    present = util.is_file(normalized),
    relative_path = relative_path(change, normalized),
  }
end

local function collect_spec_artifacts(change)
  local specs_dir = util.join_path(change_path(change), "specs")
  local paths = vim.fn.glob(util.join_path(specs_dir, "**", "*.md"), false, true)
  table.sort(paths)

  local specs = {}
  for _, path in ipairs(paths) do
    table.insert(specs, artifact(change, util.basename(util.dirname(path)), path))
  end

  return specs
end

local function spec_names(specs)
  local names = {}
  for _, spec in ipairs(specs or {}) do
    table.insert(names, spec.label)
  end
  return names
end

local function section_priority(section)
  return (section.todo * 2) + section.wip
end

function M.sections_needing_attention(parsed)
  local sections = {}
  for _, section in ipairs((parsed and parsed.sections) or {}) do
    if section.todo > 0 or section.wip > 0 then
      table.insert(sections, vim.deepcopy(section))
    end
  end

  table.sort(sections, function(a, b)
    if section_priority(a) == section_priority(b) then
      return a.name < b.name
    end
    return section_priority(a) > section_priority(b)
  end)

  return sections
end

function M.collect(change, parsed)
  local specs = collect_spec_artifacts(change)
  local base_path = change_path(change)
  local collected = {
    proposal = artifact(change, "Proposal", util.join_path(base_path, "proposal.md")),
    design = artifact(change, "Design", util.join_path(base_path, "design.md")),
    tasks = artifact(change, "Tasks", change.tasks_path or util.join_path(base_path, "tasks.md")),
    specs = specs,
    specs_count = #specs,
    specs_names = spec_names(specs),
    specs_dir = {
      label = "Spec deltas",
      path = util.normalize_path(util.join_path(base_path, "specs")),
      present = #specs > 0,
      relative_path = "specs",
    },
  }
  collected.proposal.summary = proposal_summary(collected.proposal.content)
  collected.sections_needing_attention = M.sections_needing_attention(parsed)
  return collected
end

function M.relative_path(change, path)
  return relative_path(change, path)
end

function M._excerpt(markdown, opts)
  return excerpt(markdown, opts)
end

function M._section_content(markdown, wanted)
  return section_content(markdown, wanted)
end

return M
