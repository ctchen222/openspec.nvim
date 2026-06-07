
## 1. Plugin extraction

- [x] 1.1 Create plugin module structure under `lua/openspec/`.
- [x] 1.2 Move discovery, parsing, UI, HTML, and command orchestration out of the personal Neovim config.
- [x] 1.3 Expose `require("openspec").setup(opts)` with configurable commands, keymaps, mappings, status states, and UI width/border.
- [x] 1.4 Add `:OpenSpecSetup` fallback command for plugin-manager setups without an explicit config block.

## 2. User-facing workflow

- [x] 2.1 Add commands for summary, remaining tasks, all tasks, next task, and HTML dashboard.
- [x] 2.2 Preserve the existing default keymap workflow: `<leader>os`, `<leader>ot`, `<leader>oa`, `<leader>on`, `<leader>oh`.
- [x] 2.3 Keep summary as a toggleable floating window.

## 3. Documentation

- [x] 3.1 Add README with installation, usage, configuration, and roadmap ideas.
- [x] 3.2 Add OpenSpec proposal, design, tasks, and capability spec delta for this extraction.
- [x] 3.3 Add project context and artifact rules to `openspec/config.yaml`.
- [x] 3.4 Add Neovim help documentation under `doc/`.
- [x] 3.5 Add release checklist documentation for plugin publishing gates.
- [x] 3.6 Add SDD control-surface roadmap and current implementation gap review.

## 4. Verification

- [x] 4.1 Add a headless parser smoke test.
- [x] 4.2 Add discovery and setup smoke tests.
- [x] 4.3 Add Makefile targets for tests, OpenSpec validation, and helptags.
- [x] 4.4 Add GitHub Actions workflow for tests and OpenSpec validation.
- [x] 4.5 Verify standalone plugin test suite.
- [x] 4.6 Verify personal Neovim config loads the local plugin and no longer depends on the old local module.
- [x] 4.7 Run OpenSpec validation.
