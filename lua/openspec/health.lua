local cli = require("openspec.cli")
local config = require("openspec.config")
local git = require("openspec.git")
local util = require("openspec.util")

local M = {}

local function finding(severity, category, message, opts)
  opts = opts or {}
  return {
    action = opts.action,
    category = category,
    lnum = opts.lnum,
    message = message,
    path = opts.path,
    severity = severity,
  }
end

local function normalize_status(payload)
  local change = payload and (payload.changeName or payload.change or {})
  if type(change) == "string" then
    return {
      name = change,
      isComplete = payload.isComplete,
      artifacts = payload.artifacts,
      applyRequires = payload.applyRequires,
      state = payload.state,
    }
  end

  return {
    name = payload.name or payload.changeName,
    isComplete = payload.isComplete or payload.complete or false,
    artifacts = payload.artifacts,
    applyRequires = payload.applyRequires,
    state = payload.state,
  }
end

local function artifact_from_status(status_payload)
  local map = {}
  for _, item in ipairs(status_payload or {}) do
    if item and item.id then
      map[item.id] = {
        path = item.outputPath,
        status = item.status or item.state,
      }
    end
  end
  return {
    proposal = map.proposal,
    design = map.design,
    specs = map.specs,
    tasks = map.tasks,
    ready = true,
    missing = {},
    summary = {},
  }
end

local function artifact_digest(change)
  return {
    proposal = util.join_path(change.path, "proposal.md"),
    design = util.join_path(change.path, "design.md"),
    specs = util.join_path(change.path, "specs"),
    tasks = change.tasks_path,
  }
end

local function is_empty_file(path)
  if not util.is_file(path) then
    return false
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return true
  end
  for _, line in ipairs(lines) do
    if line:match("%S") then
      return false
    end
  end
  return true
end

local function look_like_project_path(value)
  if not value or value == "" then
    return false
  end
  if value:match("^https?://") or value:match("^#") then
    return false
  end
  if value:match("%s") or value:match("[<>|]") or value:match("%*") then
    return false
  end
  return value:find("/", 1, true) ~= nil or value:match("%.md$") ~= nil
end

local function extract_references(lines)
  local refs = {}
  for lnum, line in ipairs(lines or {}) do
    for value in line:gmatch("`([^`]+)`") do
      if look_like_project_path(value) then
        table.insert(refs, { lnum = lnum, path = value })
      end
    end
    for value in line:gmatch("%(([^%)]+)%)") do
      if look_like_project_path(value) and not value:match("^https?://") then
        table.insert(refs, { lnum = lnum, path = value })
      end
    end
  end
  return refs
end

local function add_reference_findings(change, state, findings)
  local checks = {
    util.join_path(change.path, "proposal.md"),
    util.join_path(change.path, "design.md"),
    change.tasks_path,
  }
  for _, path in ipairs(checks) do
    if not util.is_file(path) then
      goto continue
    end
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
      goto continue
    end
    for _, ref in ipairs(extract_references(lines)) do
      local target = util.normalize_path(util.join_path(change.root, ref.path))
      if not util.is_file(target) then
        table.insert(
          findings,
          finding("blocker", "artifact", "Referenced project file does not exist: " .. ref.path, {
            action = "fix-reference",
            lnum = ref.lnum,
            path = path,
          })
        )
      end
    end
    ::continue::
  end
end

local function add_artifact_findings(change, parsed, findings)
  local paths = {
    util.join_path(change.path, "proposal.md"),
    util.join_path(change.path, "design.md"),
    change.tasks_path,
  }
  for _, path in ipairs(paths) do
    if not util.is_file(path) then
      table.insert(findings, finding("blocker", "artifact", "Missing required artifact: " .. util.basename(path), { path = path }))
    elseif is_empty_file(path) then
      table.insert(findings, finding("warning", "artifact", path .. " is empty", { path = path }))
    end
  end

  local spec_glob = util.join_path(change.path, "specs", "*", "spec.md")
  local specs = vim.fn.glob(spec_glob, false, true)
  if specs and #specs == 0 then
    table.insert(findings, finding("warning", "artifact", "No spec delta files found."))
  else
    for _, spec_path in ipairs(specs) do
      local ok, lines = pcall(vim.fn.readfile, spec_path)
      if not ok then
        table.insert(findings, finding("blocker", "artifact", "Cannot read spec artifact: " .. spec_path, { path = spec_path }))
      elseif #lines == 0 then
        table.insert(findings, finding("blocker", "artifact", "Spec artifact is empty: " .. spec_path, { path = spec_path }))
      end
    end
  end

  if parsed and parsed.total == 0 then
    table.insert(findings, finding("warning", "task", "tasks.md has no parsed checkbox tasks."))
  end
end

local function add_git_findings(change, findings)
  local info = git.info(change.root or "")
  if info.branch == nil and change.name then
    table.insert(findings, finding("warning", "git", "Could not detect current branch."))
  end
  if info.branch and change.name and not info.branch:find(change.name, 1, true) then
    table.insert(
      findings,
      finding("warning", "git", "Current branch does not include the selected change name: " .. info.branch, {
        action = "check-branch",
      })
    )
  end
  if #info.dirty > 0 then
    table.insert(
      findings,
      finding("warning", "git", "Working tree has local changes: " .. #info.dirty .. " entry(s).", {
        action = "review-diff",
      })
    )
  end
  return info
end

local function cli_error_finding(error_message, findings)
  table.insert(findings, finding("info", "openspec", "OpenSpec CLI unavailable: " .. tostring(error_message)))
end

local function apply_recommendation(state, parsed, cli_state)
  local recommendations = {}

  local remaining = parsed and (parsed.total - parsed.done) or 0
  if cli_state and cli_state.isComplete then
    table.insert(
      recommendations,
      {
        command = "/opsx:verify " .. state.change_name,
        skill = "$openspec-verify-change " .. state.change_name,
        reason = "All tasks are complete; verify OpenSpec health before archive.",
      }
    )
    table.insert(
      recommendations,
      {
        command = "/opsx:archive " .. state.change_name,
        skill = "$openspec-archive-change " .. state.change_name,
        reason = "If verify passes, archive this change.",
      }
    )
    return recommendations
  end

  if remaining > 0 then
    table.insert(
      recommendations,
      {
        command = "/opsx:apply " .. state.change_name,
        skill = "$openspec-apply-change " .. state.change_name,
        reason = "Continue implementation for this change.",
      }
    )
    return recommendations
  end

  table.insert(
    recommendations,
    {
      command = "/opsx:continue " .. state.change_name,
      skill = "$openspec-continue " .. state.change_name,
      reason = "No remaining tasks parsed; inspect artifact completeness and re-run status.",
    }
  )
  return recommendations
end

local function validate_item(change_name, summary, findings)
  if not summary then
    return
  end

  local totals = nil
  if summary.summary and summary.summary.totals then
    totals = summary.summary.totals
  elseif summary.totals then
    totals = summary.totals
  end
  if totals then
    local failed = totals.failed or 0
    local blocked = totals.blockers or totals.errors or 0
    if failed > 0 or blocked > 0 then
      table.insert(
        findings,
        finding("blocker", "validation", "OpenSpec validation failed for " .. change_name .. ".")
      )
      return
    end
  end

  if summary.ok == false then
    table.insert(findings, finding("blocker", "validation", "OpenSpec validation failed for " .. change_name))
  end
end

function M.evaluate(change, parsed, opts)
  opts = opts or {}
  local findings = {}
  local change_name = change.name or "(unknown)"
  local root = change.root or opts.root or vim.fn.getcwd()

  local health_cfg = config.get().health or {}
  local validation_cfg = health_cfg.validation
  local cli_validation_enabled = true
  if type(validation_cfg) == "boolean" then
    cli_validation_enabled = validation_cfg
  elseif type(validation_cfg) == "table" and validation_cfg.enabled ~= nil then
    cli_validation_enabled = validation_cfg.enabled ~= false
  end

  local cli_status
  local cli_instructions
  local cli_validation
  local cli_artifacts = artifact_from_status({})
  local cli_available = false
  local validation = { enabled = cli_validation_enabled, ok = true, output = {} }

  if cli.has_executable() then
    cli_available = true
    cli_status, cli_instructions, cli_validation = nil, nil, nil
    local status_err
    cli_status, status_err = cli.status(change_name, root)
    if not status_err then
      local normalized = normalize_status(cli_status)
      cli_status = normalized
      cli_artifacts = artifact_from_status(cli_status.artifacts or {})
      cli_status.isComplete = cli_status.isComplete or cli_status.state == "complete"
    else
      local status_message = status_err or "status check failed"
      cli_status = { name = change_name }
      cli_error_finding(status_message, findings)
    end

    cli_instructions, status_err = cli.instructions_apply(change_name, root)
    if status_err then
      -- non-blocking; continue with local inference.
    end

    if cli_validation_enabled then
      cli_validation, status_err = cli.validate({ root = root })
      if status_err then
        validation = { enabled = true, ok = false, output = { status_err } }
        table.insert(findings, finding("blocker", "validation", "OpenSpec validation command failed.", { action = "openspec-validate" }))
      else
        validate_item(change_name, cli_validation, findings)
        validation.ok = true
        validation.output = cli_validation
        validation.enabled = true
      end
    else
      validation = { enabled = false, ok = true, output = {} }
    end
  else
    cli_error_finding("disabled or not available", findings)
  end

  local selected_task = parsed and (opts.task or parsed.next_task)
  local status = {
    cliAvailable = cli_available,
    enabled = cli.has_executable(),
    status = cli_status,
    instructions = cli_instructions,
    validation = validation,
    artifacts = cli_artifacts,
    changeName = change_name,
  }

  add_artifact_findings(change, parsed, findings)
  add_reference_findings(change, status, findings)
  local git_info = add_git_findings(change, findings)

  if parsed and parsed.total == 0 and cli_status and cli_status.isComplete then
    table.insert(findings, finding("warning", "task", "No tasks were parsed as checklist items."))
  end

  local summary = {
    change_name = change_name,
    cli = status,
    git = git_info,
    selected_task = selected_task,
    findings = findings,
    artifact_digest = artifact_digest(change),
    recommendations = apply_recommendation({ change_name = change_name }, parsed, cli_status),
  }
  summary.recommendations = summary.recommendations or apply_recommendation({ change_name = change_name }, parsed, cli_status)

  return summary
end

function M._finding(severity, category, message, opts)
  return finding(severity, category, message, opts)
end

return M
