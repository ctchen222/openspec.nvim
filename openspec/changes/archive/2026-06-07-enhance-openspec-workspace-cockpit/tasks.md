## 1. Artifact model

- [x] 1.1 Add a dependency-free artifact digest helper for proposal, design, tasks, and spec delta presence. <!-- openspec.nvim:task-id=tsk_workspace_artifacts_presence -->
- [x] 1.2 Extract proposal summary or first useful excerpt for workspace display. <!-- openspec.nvim:task-id=tsk_workspace_proposal_excerpt -->
- [x] 1.3 Report spec delta count, names, and change-relative artifact paths. <!-- openspec.nvim:task-id=tsk_workspace_spec_delta_digest -->
- [x] 1.4 Reuse parsed task data to identify task sections needing attention without reparsing `tasks.md`. <!-- openspec.nvim:task-id=tsk_workspace_attention_sections -->

## 2. Workspace cockpit rendering

- [x] 2.1 Extend workspace output with a top-level next upstream action section before detailed findings. <!-- openspec.nvim:task-id=tsk_workspace_next_action_top -->
- [x] 2.2 Add an artifact digest section with proposal/design/tasks/spec status and paths. <!-- openspec.nvim:task-id=tsk_workspace_artifact_digest_render -->
- [x] 2.3 Add a sections-needing-attention section with done, todo, and WIP counts. <!-- openspec.nvim:task-id=tsk_workspace_attention_render -->
- [x] 2.4 Preserve selected task, branch/worktree context, local findings, and quickfix behavior without workflow gates. <!-- openspec.nvim:task-id=tsk_workspace_preserve_local_health_model -->
- [x] 2.5 Render `:OpenSpecWorkspace` as a Neovim-native scratch workspace surface that does not open a browser or write reports into the project tree. <!-- openspec.nvim:task-id=tsk_workspace_native_surface -->

## 3. Mapping and configuration

- [x] 3.1 Add `mappings.workspace = "<leader>ow"` to default configuration. <!-- openspec.nvim:task-id=tsk_workspace_default_mapping -->
- [x] 3.2 Register the workspace keymap when default keymaps are enabled. <!-- openspec.nvim:task-id=tsk_workspace_keymap_register -->
- [x] 3.3 Respect custom `mappings.workspace` values. <!-- openspec.nvim:task-id=tsk_workspace_custom_mapping -->
- [x] 3.4 Ensure `keymaps = false` disables the workspace mapping while keeping `:OpenSpecWorkspace` available. <!-- openspec.nvim:task-id=tsk_workspace_disable_mapping -->

## 4. Documentation

- [x] 4.1 Update README usage and configuration docs with the summary/workspace/HTML information ladder. <!-- openspec.nvim:task-id=tsk_workspace_readme_docs -->
- [x] 4.2 Update help docs for `:OpenSpecWorkspace` and the new default workspace mapping. <!-- openspec.nvim:task-id=tsk_workspace_help_docs -->
- [x] 4.3 Document that the cockpit is a digest, not a full artifact preview or picker. <!-- openspec.nvim:task-id=tsk_workspace_digest_boundary_docs -->
- [x] 4.4 Remove obsolete gate/preflight language from workspace cockpit docs and specs. <!-- openspec.nvim:task-id=tsk_workspace_remove_gate_language -->

## 5. Tests and verification

- [x] 5.1 Add headless tests for artifact digest extraction and missing artifact handling. <!-- openspec.nvim:task-id=tsk_workspace_artifact_tests -->
- [x] 5.2 Add workspace rendering tests for artifact digest, sections needing attention, local findings, and next upstream action. <!-- openspec.nvim:task-id=tsk_workspace_render_tests -->
- [x] 5.3 Add setup/keymap tests for default, custom, and disabled workspace mappings. <!-- openspec.nvim:task-id=tsk_workspace_keymap_tests -->
- [x] 5.4 Run `make check`. <!-- openspec.nvim:task-id=tsk_workspace_make_check -->
- [x] 5.5 Run strict OpenSpec validation for this change and all changes. <!-- openspec.nvim:task-id=tsk_workspace_strict_validation -->
