local util = require("openspec.util")

local M = {}

local function read_lines(path)
  if not path or not util.is_file(path) then
    return {}
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end
  return lines
end

local function excerpt(path, limit)
  local source = read_lines(path)
  local lines = {}
  for index, line in ipairs(source) do
    if index > limit then
      table.insert(lines, "...")
      break
    end
    table.insert(lines, line)
  end
  return lines
end

local function push_section(lines, title, body)
  table.insert(lines, "")
  table.insert(lines, "## " .. title)
  table.insert(lines, "")
  if #body == 0 then
    table.insert(lines, "_No content available._")
  else
    vim.list_extend(lines, body)
  end
end

local function artifact_path(change, name)
  return util.join_path(change.path, name)
end

local function spec_paths(change)
  return vim.fn.glob(util.join_path(change.path, "specs", "*", "spec.md"), false, true)
end

function M.lines(change, parsed, state)
  local task = state.selected_task
  local git_info = state.git or {}
  local validation = state.cli and state.cli.validation or {}
  local validation_state = validation.ok and "passed" or (validation.enabled == false and "disabled" or "failed")
  local recommendation = state.recommendations or {}
  local primary = recommendation[1]
  local recommendation_text = "none"
  if primary then
    if primary.skill and primary.skill ~= "" and primary.skill ~= primary.command then
      recommendation_text = primary.command .. " / " .. primary.skill
    else
      recommendation_text = primary.command
    end
  end
  local lines = {
    "# OpenSpec Upstream Context",
    "",
    "This context helps prepare a downstream OpenSpec action.",
    "openspec.nvim does not own apply/verify/archive lifecycles; it only prepares context and shows local findings.",
    "",
    "- Change: `" .. change.name .. "`",
    "- Task line: " .. (task and tostring(task.lnum) or "(none)"),
    "- Task status: `" .. (task and task.status or "(none)") .. "`",
    "- Task text: " .. (task and task.text or "(none)"),
    "- Branch: `" .. (git_info.branch or "(unknown)") .. "`",
    "- Dirty entries: " .. tostring(#(git_info.dirty or {})),
    "- Validation: `" .. validation_state .. "`",
    "- Recommended upstream action: `" .. recommendation_text .. "`",
  }

  table.insert(lines, "")
  table.insert(lines, "## Local Health Findings")
  if #state.findings == 0 then
    table.insert(lines, "- No findings.")
  else
    for _, finding in ipairs(state.findings or {}) do
      table.insert(lines, "- [" .. (finding.severity or "info") .. "/" .. finding.category .. "] " .. finding.message)
    end
  end

  push_section(lines, "Allowed Scope", {
    "- Implement only the selected task.",
    "- Update OpenSpec artifacts only when implementation proves the task/spec is stale or incomplete.",
    "- Touch code, tests, and docs that directly support the selected task.",
  })

  push_section(lines, "Forbidden Scope", {
    "- Do not treat this buffer as approval to run lifecycle actions.",
    "- Do not archive or sync this change from this context alone.",
  })

  push_section(lines, "Verification Commands", {
    "- `openspec validate --all --strict`",
    "- `make check` when available, otherwise the closest documented project check.",
  })

  push_section(lines, "Model Control Guidance", {
    "- Model guidance in this context is advisory for copied sessions.",
    "- Existing Codex/Claude sessions started separately will not auto-switch model from pasted text.",
    "- To enforce model selection, run `:OpenSpecImplement` (for example `:OpenSpecImplement codex profile=implementation`).",
  })

  push_section(lines, "Stop Conditions", {
    "- Stop if implementation requires expanding the selected task scope.",
    "- Stop if a referenced file is missing and the correct replacement is unclear.",
    "- Stop if local changes cannot be mapped back to the selected task.",
    "- Stop if validation or project checks fail after a focused fix attempt.",
  })

  push_section(lines, "Proposal", excerpt(artifact_path(change, "proposal.md"), 80))
  push_section(lines, "Design", excerpt(artifact_path(change, "design.md"), 120))
  push_section(lines, "Tasks", excerpt(change.tasks_path, 120))

  for _, path in ipairs(spec_paths(change)) do
    push_section(lines, "Spec Delta: " .. util.basename(util.dirname(path)), excerpt(path, 120))
  end

  return lines
end

function M.open(change, parsed, state)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "OpenSpec Upstream Context")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.lines(change, parsed, state))
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_current_buf(buf)
  util.notify("Opened OpenSpec agent context buffer.")
end

return M
