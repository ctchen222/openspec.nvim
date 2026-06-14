.PHONY: test validate check helptags

test:
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/parser_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/discovery_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/selection_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/setup_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/setup_custom_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/setup_no_keymaps_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/task_status_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/implement_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/init_implement_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/health_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/context_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/skills_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/artifacts_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/html_spec.lua
	nvim --headless -u NONE --cmd 'set shadafile=NONE' -l tests/ui_spec.lua

validate:
	openspec validate --all --strict

check: test validate

helptags:
	nvim --headless -u NONE --cmd 'set shadafile=NONE' --cmd 'helptags doc' +qa
