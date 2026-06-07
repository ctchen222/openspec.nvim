# Development

## Local checks

Run the Neovim headless test suite:

```sh
make test
```

Validate OpenSpec artifacts:

```sh
make validate
```

Run both:

```sh
make check
```

Generate Neovim help tags:

```sh
make helptags
```

## Git history

Commit messages in this repository MUST follow the Conventional Commits
specification.

Use the format:

```text
type(scope): description
```

Examples:

```text
feat(workspace): add active change overview
fix(discovery): handle archived changes correctly
docs(readme): clarify upstream workflow boundary
test(ui): cover branch mismatch findings
refactor(health): simplify git warning generation
chore(ci): run OpenSpec validation on pull requests
```

Keep the subject line short, imperative, and specific to the change being
committed.

## Manual smoke test

Install the plugin locally from your Neovim config:

```lua
{
  dir = "/Users/ctchen/Development/project/openspec.nvim",
  name = "openspec.nvim",
  config = function()
    require("openspec").setup()
  end,
}
```

Then open a repository containing `openspec/changes/<change>/tasks.md` and verify:

- `<leader>os` toggles the summary window with progress, next task, and remaining sections.
- `<leader>oh` opens a temporary HTML change report with proposal, design, spec delta, and tasks.

## Release criteria

Before publishing this as a standalone plugin repository:

- Parser tests cover default and custom task states.
- Discovery tests cover current-buffer change selection and multi-change selection.
- README and help docs describe all public commands and setup options.
- Optional integrations such as Telescope or Trouble stay optional.
- OpenSpec artifacts validate strictly.
- CI runs the headless Neovim tests and OpenSpec validation on pull requests.

See [docs/release-checklist.md](docs/release-checklist.md) for the full pre-release checklist.
