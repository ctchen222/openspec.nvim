## Context

`openspec.nvim` exposes three reading surfaces:

- `<leader>os` / `:OpenSpecTasksSummary`: compact task progress summary.
- `:OpenSpecWorkspace`: Neovim-native workspace cockpit.
- `<leader>oh` / `:OpenSpecTasksHtml`: full browser-readable change report.

The workspace is the middle layer. It should provide enough artifact and local
state to decide what to inspect or run next, without duplicating the full HTML
report and without recreating upstream OpenSpec lifecycle automation.

The archived version of this change preserved the old four-gate model. That is
now obsolete. The workspace should show local health findings and upstream
recommendations, not workflow gates.

## Goals / Non-Goals

**Goals:**

- Make `:OpenSpecWorkspace` the primary Neovim-native cockpit for one selected
  OpenSpec change.
- Show enough artifact context to decide the next action without opening the
  HTML report.
- Show selected task, Git/worktree context, local health findings, and upstream
  recommendation in one workspace surface.
- Keep findings quickfix-capable when file coordinates exist.
- Keep the default, configurable workspace keymap without changing summary or
  HTML mappings.
- Keep the implementation dependency-free and readable in minimal Neovim setups.

**Non-Goals:**

- Do not duplicate the full HTML report inside Neovim.
- Do not add Telescope, Trouble, markdown preview, browser, embedding, or LLM
  dependencies.
- Do not show or preserve workflow gates.
- Do not automatically apply, verify, sync, archive, mutate tasks, switch
  worktrees, or launch terminal agents from the cockpit.
- Do not make generated summaries canonical; OpenSpec markdown remains the
  source of truth.

## Decisions

### Decision: Keep `:OpenSpecWorkspace` as the middle layer

Adding another command such as `:OpenSpecStatus` or `:OpenSpecCockpit` would
split the mental model. `:OpenSpecWorkspace` already names the in-editor control
surface and should remain the command for this layer.

The view should render:

```text
OpenSpec Workspace
  Change / branch / path / progress
  Next upstream action
  Selected task
  Artifact digest
  Sections needing attention
  Local health findings
  Source paths / commands
```

It should not render a gate timeline.

### Decision: Use an artifact digest, not a full preview

The workspace needs enough artifact information to guide attention:

- proposal/design/tasks/spec presence;
- proposal summary or useful excerpt;
- spec delta count and names;
- task progress and sections needing attention;
- change-relative artifact paths.

The full artifact body remains in source Markdown and the HTML report.

### Decision: Surface local health findings, not lifecycle gates

Findings should explain local evidence:

- OpenSpec CLI missing or validation failed.
- Required artifacts are missing or empty.
- Referenced project files are missing.
- Current branch does not appear to match the selected change.
- Working tree is dirty.

These are not lifecycle gates. They help users decide whether to continue,
inspect artifacts, or run an upstream command.

### Decision: Recommend upstream actions

The workspace may recommend upstream commands and skills, such as:

- `/opsx:apply <change>` / `$openspec-apply-change <change>` when tasks remain.
- `/opsx:verify <change>` / `$openspec-verify-change <change>` when tasks are complete.
- `/opsx:archive <change>` / `$openspec-archive-change <change>` after verification.

The plugin must not execute those lifecycle actions.

### Decision: Keep navigation light

The cockpit should expose artifact paths and quickfix entries for findings. It
does not need to become a picker in this change. Future Telescope/Trouble
adapters can provide richer navigation.

## Migration Plan

1. Keep or extract the artifact model for proposal, design, spec delta, and task
   digest data.
2. Ensure workspace rendering includes artifact digest, selected task, sections
   needing attention, Git context, local findings, and upstream action.
3. Remove old gate terminology from proposal/design/spec/tasks/docs/tests.
4. Keep `mappings.workspace = "<leader>ow"` and bind it when default keymaps are
   enabled.
5. Update README/help/tests to describe the summary/workspace/HTML information
   ladder.
6. Run headless Neovim tests and strict OpenSpec validation.
