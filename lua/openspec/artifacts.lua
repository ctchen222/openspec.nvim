local util = require("openspec.util")

local M = {}
local collect_spec_artifacts

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

local function artifact_target(change, kind, path, label, lnum)
  local normalized = util.normalize_path(path)
  return {
    kind = kind,
    path = normalized,
    absolute_path = normalized,
    display_path = relative_path(change, normalized),
    relative_path = relative_path(change, normalized),
    content = read_file(normalized),
    label = label,
    lnum = lnum,
    present = util.is_file(normalized),
  }
end

local function spec_targets(change, target_spec)
  local specs = collect_spec_artifacts(change)
  local targets = {}

  for _, spec in ipairs(specs) do
    table.insert(targets, artifact_target(change, "specs", spec.path, spec.label))
  end

  if not target_spec then
    return targets
  end

  local selected = nil
  local selector = tostring(target_spec)
  for _, target in ipairs(targets) do
    if target_spec == target.label or selector == target.relative_path or selector == target.label then
      selected = target
      break
    end
  end

  if selected then
    return { selected }
  end

  if type(target_spec) == "number" and target_spec >= 1 and target_spec <= #targets then
    return { targets[target_spec] }
  end

  return {}
end

collect_spec_artifacts = function(change)
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
  local proposal = M.resolve_artifact_targets(change, "proposal")[1]
  local design = M.resolve_artifact_targets(change, "design")[1]
  local tasks_target = M.resolve_artifact_targets(change, "tasks")[1]
  local spec_targets = M.resolve_artifact_targets(change, "specs")
  local base_path = change_path(change)
  local specs_count = #spec_targets
  local specs_names = spec_names(collect_spec_artifacts(change))
  local collected = {
    proposal = proposal,
    design = design,
    tasks = tasks_target,
    specs = spec_targets,
    specs_count = specs_count,
    specs_names = specs_names,
    specs_dir = {
      label = "Spec deltas",
      path = util.normalize_path(util.join_path(base_path, "specs")),
      present = specs_count > 0,
      relative_path = "specs",
    },
  }
  collected.proposal.summary = proposal_summary(collected.proposal.content)
  collected.sections_needing_attention = M.sections_needing_attention(parsed)
  return collected
end

function M.resolve_artifact_targets(change, kind, opts)
  opts = opts or {}
  local target_kind = (kind or ""):lower()
  local path = change_path(change)
  if target_kind == "proposal" then
    return { artifact_target(change, "proposal", util.join_path(path, "proposal.md")) }
  end
  if target_kind == "design" then
    return { artifact_target(change, "design", util.join_path(path, "design.md")) }
  end
  if target_kind == "tasks" then
    return { artifact_target(change, "tasks", change.tasks_path or util.join_path(path, "tasks.md")) }
  end
  if target_kind == "specs" or target_kind == "spec" then
    return spec_targets(change, opts.spec or opts.label)
  end
  return {}
end

function M.resolve_artifact_target(change, kind, opts)
  local targets = M.resolve_artifact_targets(change, kind, opts)
  return targets[1]
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
