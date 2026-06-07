local tasks = require("openspec.tasks")
local util = require("openspec.util")

local M = {}

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

local function artifact(path, label)
  return {
    content = read_file(path),
    label = label,
    path = path,
  }
end

local function collect_spec_artifacts(change)
  local paths = vim.fn.glob(util.join_path(change.path, "specs", "**", "*.md"), false, true)
  table.sort(paths)

  local specs = {}
  for _, path in ipairs(paths) do
    table.insert(specs, artifact(util.normalize_path(path), util.basename(util.dirname(path))))
  end

  return specs
end

local function collect_artifacts(change)
  return {
    proposal = artifact(util.join_path(change.path, "proposal.md"), "Proposal"),
    design = artifact(util.join_path(change.path, "design.md"), "Design"),
    tasks = artifact(change.tasks_path or util.join_path(change.path, "tasks.md"), "Tasks"),
    specs = collect_spec_artifacts(change),
  }
end

local function is_present(item)
  return item and item.content and item.content ~= ""
end

local function artifact_count(artifacts)
  local count = 0
  if is_present(artifacts.proposal) then
    count = count + 1
  end
  if is_present(artifacts.design) then
    count = count + 1
  end
  if is_present(artifacts.tasks) then
    count = count + 1
  end
  if #artifacts.specs > 0 then
    count = count + 1
  end
  return count
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

  local content = table.concat(collected, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
  if content == "" then
    return nil
  end
  return content
end

local function trim(value)
  local trimmed = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return trimmed
end

local function excerpt(markdown)
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
      if #parts >= 2 then
        break
      end
    end
  end

  local result = table.concat(parts, " ")
  if #result > 260 then
    result = result:sub(1, 257) .. "..."
  end
  return result
end

local function proposal_summary(artifacts)
  return excerpt(section_content(artifacts.proposal.content, "Summary") or artifacts.proposal.content)
end

local function push(lines, value)
  table.insert(lines, value)
end

local function flatten_lines(lines)
  local flattened = {}

  for _, value in ipairs(lines) do
    for _, line in ipairs(vim.split(value, "\n", { plain = true })) do
      table.insert(flattened, line)
    end
  end

  return flattened
end

local function path_label(change, path)
  if not path then
    return ""
  end

  local normalized = util.normalize_path(path)
  local change_path = util.normalize_path(change.path)
  local prefix = change_path .. "/"
  if normalized == change_path then
    return "."
  end
  if normalized:sub(1, #prefix) == prefix then
    return normalized:sub(#prefix + 1)
  end
  return normalized
end

local function inline_markdown(text)
  local escaped = util.escape_html(text)
  escaped = escaped:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')
  escaped = escaped:gsub("`([^`]+)`", "<code>%1</code>")
  escaped = escaped:gsub("%*%*([^*]+)%*%*", "<strong>%1</strong>")
  return escaped
end

local function split_table_row(line)
  local trimmed = trim(line):gsub("^|", ""):gsub("|$", "")
  local cells = {}
  for cell in trimmed:gmatch("([^|]+)") do
    table.insert(cells, trim(cell))
  end
  return cells
end

local function is_table_separator(line)
  return trim(line):match("^:?-+:?%s*|") or trim(line):match("^|%s*:?-+:?")
end

local function table_row(cells, tag)
  local parts = { "<tr>" }
  for _, cell in ipairs(cells) do
    push(parts, "<" .. tag .. ">" .. inline_markdown(cell) .. "</" .. tag .. ">")
  end
  push(parts, "</tr>")
  return table.concat(parts)
end

local function render_markdown(markdown)
  if not markdown or markdown == "" then
    return "<p class=\"muted\">No content.</p>"
  end

  local source = vim.split(markdown, "\n", { plain = true })
  local lines = {}
  local paragraph = {}
  local list_type = nil
  local in_code = false
  local code_lines = {}
  local i = 1

  local function close_paragraph()
    if #paragraph == 0 then
      return
    end
    push(lines, "<p>" .. inline_markdown(table.concat(paragraph, " ")) .. "</p>")
    paragraph = {}
  end

  local function close_list()
    if list_type then
      push(lines, "</" .. list_type .. ">")
      list_type = nil
    end
  end

  local function open_list(kind)
    close_paragraph()
    if list_type ~= kind then
      close_list()
      push(lines, "<" .. kind .. ">")
      list_type = kind
    end
  end

  local function close_code()
    if not in_code then
      return
    end
    push(lines, "<pre class=\"code-block\"><code>" .. util.escape_html(table.concat(code_lines, "\n")) .. "</code></pre>")
    code_lines = {}
    in_code = false
  end

  while i <= #source do
    local line = source[i]
    local stripped = trim(line)

    if stripped:match("^```") then
      if in_code then
        close_code()
      else
        close_paragraph()
        close_list()
        in_code = true
        code_lines = {}
      end
    elseif in_code then
      push(code_lines, line)
    elseif stripped == "" then
      close_paragraph()
      close_list()
    else
      local marks, title = stripped:match("^(#+)%s+(.+)$")
      local bullet = stripped:match("^[-*+]%s+(.+)$")
      local ordered = stripped:match("^%d+%.%s+(.+)$")

      if marks and title then
        close_paragraph()
        close_list()
        local level = math.min(#marks + 1, 4)
        push(lines, "<h" .. level .. ">" .. inline_markdown(title:gsub("%s+#*$", "")) .. "</h" .. level .. ">")
      elseif bullet then
        open_list("ul")
        push(lines, "<li>" .. inline_markdown(bullet) .. "</li>")
      elseif ordered then
        open_list("ol")
        push(lines, "<li>" .. inline_markdown(ordered) .. "</li>")
      elseif line:find("|", 1, true) and source[i + 1] and is_table_separator(source[i + 1]) then
        close_paragraph()
        close_list()
        push(lines, "<table>")
        push(lines, "<thead>" .. table_row(split_table_row(line), "th") .. "</thead>")
        push(lines, "<tbody>")
        i = i + 2
        while i <= #source and source[i]:find("|", 1, true) and trim(source[i]) ~= "" do
          push(lines, table_row(split_table_row(source[i]), "td"))
          i = i + 1
        end
        push(lines, "</tbody></table>")
        i = i - 1
      else
        close_list()
        push(paragraph, stripped)
      end
    end

    i = i + 1
  end

  close_code()
  close_paragraph()
  close_list()

  if #lines == 0 then
    return "<p class=\"muted\">No content.</p>"
  end
  return table.concat(lines, "\n")
end

local function status_badge(ok)
  if ok then
    return "<span class=\"badge ok\">Found</span>"
  end
  return "<span class=\"badge missing\">Missing</span>"
end

local function artifact_row(change, label, path, ok)
  return "<li><strong>"
    .. util.escape_html(label)
    .. "</strong> "
    .. status_badge(ok)
    .. " <span class=\"path\">"
    .. util.escape_html(path_label(change, path))
    .. "</span></li>"
end

local function markdown_block(change, item)
  if not is_present(item) then
    return "<div class=\"markdown-body\"><p class=\"muted\">Artifact not found.</p><p class=\"path\">"
      .. util.escape_html(path_label(change, item.path))
      .. "</p></div>"
  end

  return "<div class=\"markdown-body\">"
    .. render_markdown(item.content)
    .. "</div>"
end

local function details(title, meta, body, open)
  local open_attr = open and " open" or ""
  return "<details"
    .. open_attr
    .. "><summary><span>"
    .. util.escape_html(title)
    .. "</span><span class=\"meta\">"
    .. util.escape_html(meta or "")
    .. "</span></summary>"
    .. body
    .. "</details>"
end

local function task_sections(parsed)
  local lines = {}

  for _, section in ipairs(parsed.sections) do
    push(lines, "<div class=\"task-section\">")
    push(
      lines,
      "<h3>"
        .. util.escape_html(section.name)
        .. " <span class=\"meta\">"
        .. section.done
        .. "/"
        .. section.total
        .. " done, todo:"
        .. section.todo
        .. " wip:"
        .. section.wip
        .. " skipped:"
        .. section.skipped
        .. "</span></h3>"
    )
    push(lines, "<ol class=\"task-list\">")
    for _, task in ipairs(parsed.tasks) do
      if task.section == section.name then
        local status = util.escape_html(task.status)
        push(
          lines,
        "<li class=\"task-row "
            .. status
            .. "\" data-line=\""
            .. task.lnum
            .. "\"><span class=\"status-pill status-"
            .. status
            .. "\">"
            .. util.escape_html(tasks.status_label(task.status))
            .. "</span><span class=\"task-text\">"
            .. util.escape_html(task.text)
            .. "</span></li>"
        )
      end
    end
    push(lines, "</ol></div>")
  end

  if #lines == 0 then
    return "<p class=\"muted\">No task sections found.</p>"
  end

  return table.concat(lines, "\n")
end

local function spec_details(change, artifacts)
  if #artifacts.specs == 0 then
    return "<p class=\"muted\">No spec delta files found.</p>"
  end

  local lines = {}
  for _, spec in ipairs(artifacts.specs) do
    push(lines, details(spec.label, path_label(change, spec.path), markdown_block(change, spec), false))
  end

  return table.concat(lines, "\n")
end

local function html_lines(change, parsed)
  local artifacts = collect_artifacts(change)
  local summary = proposal_summary(artifacts)
  if summary == "" then
    summary = "No proposal summary found. Expand the artifacts below for details."
  end

  local remaining = parsed.counts.todo + parsed.counts.wip
  local lines = {
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>OpenSpec Change Report - " .. util.escape_html(parsed.change_name) .. "</title>",
    "<style>",
    ":root{color-scheme:dark}",
    "body{margin:0;background:#0b1020}",
    ".page{min-height:100vh;box-sizing:border-box;padding:32px;font-family:\"Avenir Next\",\"Helvetica Neue\",\"Noto Sans TC\",sans-serif;line-height:1.58;color:var(--ink);background:var(--bg);--bg:#0b1020;--surface:#111827;--surface-2:#0f172a;--ink:#e5edf8;--muted:#9aa8bd;--line:#263247;--soft:#1a2436;--accent:#60a5fa;--code:#182235;--ok-bg:#153b25;--ok-ink:#86efac;--missing-bg:#4a1d23;--missing-ink:#fecdd3;--todo-bg:#4a1d23;--todo-ink:#fecdd3;--wip-bg:#3f2d12;--wip-ink:#facc15;--skip-bg:#263247;--skip-ink:#cbd5e1}",
    ".theme-control:checked+.page{color-scheme:light;--bg:#f6f7f9;--surface:#ffffff;--surface-2:#ffffff;--ink:#172033;--muted:#647084;--line:#d9dee8;--soft:#eef2f7;--accent:#2563eb;--code:#f2f5fa;--ok-bg:#dcfce7;--ok-ink:#166534;--missing-bg:#fee2e2;--missing-ink:#991b1b;--todo-bg:#fee2e2;--todo-ink:#991b1b;--wip-bg:#fef3c7;--wip-ink:#92400e;--skip-bg:#e2e8f0;--skip-ink:#475569}",
    "main{max-width:1080px;margin:0 auto}",
    ".topbar{display:flex;align-items:flex-start;justify-content:space-between;gap:20px;margin-bottom:18px}",
    ".theme-control{position:absolute;width:1px;height:1px;opacity:0;pointer-events:none}",
    ".theme-control:focus-visible+.page .theme-toggle{outline:2px solid var(--accent);outline-offset:3px}",
    ".theme-toggle{width:42px;height:42px;display:inline-grid;place-items:center;border:1px solid var(--line);background:var(--surface);color:var(--ink);border-radius:8px;padding:0;cursor:pointer;user-select:none}",
    ".theme-toggle:hover{border-color:var(--accent)}",
    ".theme-toggle svg{width:20px;height:20px;stroke:currentColor;stroke-width:2;fill:none;stroke-linecap:round;stroke-linejoin:round}",
    ".icon-moon{display:none}",
    ".theme-control:checked+.page .icon-sun{display:none}",
    ".theme-control:checked+.page .icon-moon{display:block}",
    "h1{font-size:30px;margin-bottom:8px}",
    "h2{font-size:20px;margin:0 0 12px}",
    "h3{font-size:18px;margin:24px 0 8px}",
    "h4{font-size:15px;margin:18px 0 6px;color:var(--muted);text-transform:uppercase;letter-spacing:.03em}",
    ".lede{font-size:17px;color:var(--ink);max-width:76ch}",
    ".summary{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;margin:24px 0}",
    ".card,section,details{background:var(--surface);border:1px solid var(--line);border-radius:8px}",
    ".card{padding:14px}",
    "section{padding:18px;margin:16px 0}",
    "details{padding:0;margin:14px 0}",
    "summary{cursor:pointer;display:flex;align-items:center;gap:16px;padding:14px 16px;font-weight:700}",
    "summary span:first-child{margin-right:auto}",
    "details>details{border-color:var(--soft);margin-left:16px;margin-right:16px}",
    ".artifact-path,.path{color:var(--muted);font-size:13px;overflow-wrap:anywhere}",
    ".artifact-path{border-top:1px solid var(--soft);padding:12px 16px 0}",
    ".markdown-body{padding:4px 16px 18px;max-width:86ch}",
    ".markdown-body p{margin:10px 0}",
    ".markdown-body ul,.markdown-body ol{padding-left:24px;margin:10px 0 14px}",
    ".markdown-body li{margin:7px 0}",
    ".markdown-body table{border-collapse:collapse;width:100%;margin:14px 0;font-size:14px}",
    ".markdown-body th,.markdown-body td{border:1px solid var(--line);padding:8px 10px;vertical-align:top}",
    ".markdown-body th{background:var(--soft);text-align:left}",
    ".task-section{padding:10px 24px 18px 34px}",
    ".task-section h3{margin-top:10px}",
    ".task-list{list-style:none;padding-left:34px;margin:12px 0 0}",
    ".task-row{display:grid;grid-template-columns:auto 1fr;gap:8px;align-items:start;padding:7px 8px;border-radius:6px}",
    ".task-row.done{color:var(--ink);opacity:.78}",
    ".task-row.done .task-text{color:var(--muted)}",
    ".status-pill{border-radius:999px;padding:2px 8px;font-size:12px;font-weight:700;line-height:1.5}",
    ".status-done{background:var(--ok-bg);color:var(--ok-ink)}",
    ".status-todo{background:var(--todo-bg);color:var(--todo-ink)}",
    ".status-wip{background:var(--wip-bg);color:var(--wip-ink)}",
    ".status-skipped{background:var(--skip-bg);color:var(--skip-ink)}",
    ".value{font-size:24px;font-weight:700}",
    ".bar{height:12px;background:var(--soft);border-radius:999px;overflow:hidden;margin-top:12px}",
    ".fill{height:100%;background:var(--accent)}",
    "li{margin:8px 0}",
    "pre.code-block{white-space:pre-wrap;background:var(--code);color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:12px;overflow:auto}",
    ".badge{border-radius:999px;padding:2px 8px;font-size:12px;font-weight:700}",
    ".ok{background:var(--ok-bg);color:var(--ok-ink)}.missing{background:var(--missing-bg);color:var(--missing-ink)}",
    ".meta,.muted{color:var(--muted);font-weight:400}",
    "code{font-family:SFMono-Regular,Menlo,Consolas,monospace;background:var(--code);border-radius:4px;padding:2px 5px}",
    "a{color:var(--accent)}",
    "@media(max-width:760px){.page{padding:18px}.topbar{display:block}.theme-toggle{margin-top:12px}.summary{grid-template-columns:repeat(2,minmax(0,1fr))}summary{display:block}.meta{display:block;margin-top:4px}.task-section{padding-left:22px}.task-list{padding-left:26px}.task-text{grid-column:2}}",
    "</style>",
    "</head>",
    "<body><input class=\"theme-control\" id=\"theme-control\" type=\"checkbox\" aria-label=\"Toggle theme\"><div class=\"page\"><main>",
    "<div class=\"topbar\"><div><h1>OpenSpec Change Report</h1>",
    "<p><strong>" .. util.escape_html(parsed.change_name) .. "</strong></p>",
    "</div><label class=\"theme-toggle\" for=\"theme-control\" title=\"Toggle theme\"><svg class=\"icon-sun\" viewBox=\"0 0 24 24\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"></circle><path d=\"M12 2v2\"></path><path d=\"M12 20v2\"></path><path d=\"m4.93 4.93 1.41 1.41\"></path><path d=\"m17.66 17.66 1.41 1.41\"></path><path d=\"M2 12h2\"></path><path d=\"M20 12h2\"></path><path d=\"m6.34 17.66-1.41 1.41\"></path><path d=\"m19.07 4.93-1.41 1.41\"></path></svg><svg class=\"icon-moon\" viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M20.99 12.79A9 9 0 1 1 11.21 3a7 7 0 0 0 9.78 9.79Z\"></path></svg></label></div>",
    "<p class=\"lede\">" .. inline_markdown(summary) .. "</p>",
    "<p class=\"path\">" .. util.escape_html(change.path) .. "</p>",
    "<div class=\"bar\"><div class=\"fill\" style=\"width:" .. parsed.percent .. "%\"></div></div>",
    "<div class=\"summary\">",
    "<div class=\"card\"><div>Progress</div><div class=\"value\">" .. parsed.percent .. "%</div></div>",
    "<div class=\"card\"><div>Done</div><div class=\"value\">" .. parsed.done .. "/" .. parsed.total .. "</div></div>",
    "<div class=\"card\"><div>Remaining</div><div class=\"value\">" .. remaining .. "</div></div>",
    "<div class=\"card\"><div>Todo</div><div class=\"value\">" .. parsed.counts.todo .. "</div></div>",
    "<div class=\"card\"><div>Artifacts</div><div class=\"value\">" .. artifact_count(artifacts) .. "/4</div></div>",
    "</div>",
    "<section><h2>Next Action</h2>",
  }

  if parsed.next_task then
    push(
      lines,
      "<p><strong>"
        .. util.escape_html(tasks.status_label(parsed.next_task.status))
        .. "</strong> "
        .. util.escape_html(parsed.next_task.text)
        .. "</p>"
    )
  else
    push(lines, "<p>No remaining todo or WIP tasks.</p>")
  end

  push(lines, "</section>")
  push(lines, "<section><h2>Artifact Map</h2><ul>")
  push(lines, artifact_row(change, "Proposal", artifacts.proposal.path, is_present(artifacts.proposal)))
  push(lines, artifact_row(change, "Design", artifacts.design.path, is_present(artifacts.design)))
  push(lines, artifact_row(change, "Spec deltas", util.join_path(change.path, "specs"), #artifacts.specs > 0))
  push(lines, artifact_row(change, "Tasks", artifacts.tasks.path, is_present(artifacts.tasks)))
  push(lines, "</ul></section>")

  push(lines, details("Proposal", path_label(change, artifacts.proposal.path), markdown_block(change, artifacts.proposal), false))
  push(lines, details("Design", path_label(change, artifacts.design.path), markdown_block(change, artifacts.design), false))
  push(lines, details("Spec Delta", #artifacts.specs .. " file(s)", spec_details(change, artifacts), false))
  push(lines, details("Tasks", parsed.done .. "/" .. parsed.total .. " done", task_sections(parsed), true))
  push(lines, "</main></div></body></html>")

  return lines
end

local function open_file(path)
  if vim.ui and vim.ui.open then
    local ok = pcall(vim.ui.open, path)
    if ok then
      return
    end
  end

  local opener
  if vim.fn.has("mac") == 1 then
    opener = "open"
  elseif vim.fn.has("win32") == 1 then
    opener = "cmd"
  else
    opener = "xdg-open"
  end

  if opener == "cmd" then
    vim.fn.jobstart({ "cmd", "/c", "start", "", path }, { detach = true })
  else
    vim.fn.jobstart({ opener, path }, { detach = true })
  end
end

function M._html_lines(change, parsed)
  return html_lines(change, parsed)
end

function M._flatten_lines(lines)
  return flatten_lines(lines)
end

function M.open(change, parsed)
  local path = vim.fn.tempname() .. ".html"
  vim.fn.writefile(flatten_lines(html_lines(change, parsed)), path)
  open_file(path)
  util.notify("Opened OpenSpec change report: " .. path)
end

return M
