## Context

`openspec.nvim` already provides Neovim-native reading surfaces for active changes, including the compact `<leader>os` task summary, workspace cockpit, context pack, and HTML report. Archive awareness has been discussed as a read-only project-memory surface, but the navigation contract needs to be precise before implementation.

The change should keep markdown artifacts as the source of truth, avoid external Neovim dependencies, and preserve upstream OpenSpec ownership of propose/apply/verify/sync/archive lifecycles. The implementation should therefore add navigation and inspection affordances, not mutation or execution commands.

## Goals / Non-Goals

**Goals:**

- Make `:OpenSpecArchiveSearch [query]` useful as a read-only archive navigation surface.
- Let users jump from archive search results to archived proposal, design, tasks, and spec artifacts.
- Add an archive detail buffer that summarizes archived change context without mixing archived changes into active progress.
- Add matching `p/d/t/s` artifact shortcuts to the `<leader>os` summary buffer for the selected active change.
- Keep all new shortcuts buffer-local to the rendered surface.
- Reuse existing artifact parsing/discovery patterns where possible.

**Non-Goals:**

- Do not add archive, unarchive, apply, verify, sync, or task-completion lifecycle actions.
- Do not register new global/default keymaps.
- Do not change `require("openspec").setup(opts)`.
- Do not add Telescope, Trouble, RAG, embeddings, or other external dependencies.
- Do not create missing artifacts from navigation shortcuts.

## Decisions

### Use a shared artifact target resolver

Introduce or extend a small resolver that accepts a change root plus artifact kind and returns target candidates:

- `proposal` -> `proposal.md`
- `design` -> `design.md`
- `tasks` -> `tasks.md`
- `specs` -> spec delta markdown files under `specs/**/spec.md`

The resolver should return structured targets containing absolute path, display path, optional line number, and artifact kind. It should not open files itself.

Alternatives considered:

- Duplicate path logic in archive and summary buffers. This would be faster to write but makes `p/d/t/s` behavior drift across surfaces.
- Parse rendered buffer text to infer paths. This is brittle because UI copy and layout will change.

### Store line metadata for archive search buffers

Archive search rendering should maintain a line metadata table keyed by buffer line number. Result header/source lines should point to a detail action. Match lines should point to a concrete artifact path and line.

Example metadata shapes:

- `{ kind = "detail", result_index = n }`
- `{ kind = "artifact", path = "...", lnum = 42 }`

The metadata should be installed as buffer-local state rather than inferred from text.

Alternatives considered:

- Recompute target from the cursor line text. This makes snippets and display formatting part of the behavior contract.
- Use extmarks only. Extmarks are useful for highlights, but a plain Lua metadata table is easier to unit test.

### Keep opening behavior source-window aware

Scratch buffers should remember the source window that launched them. Artifact opening should prefer that source window when it is still valid, falling back to the current window otherwise.

This keeps the archive/search buffer intact as a navigation surface instead of replacing it whenever the user jumps to an artifact.

Alternatives considered:

- Always open in the current window. This is simpler but destroys the search/detail context too easily.
- Always open a split. This changes user layout unexpectedly and should remain out of scope unless users ask for configurable layout later.

### Install buffer-local shortcuts only

Archive search, archive detail, and summary surfaces should install `p/d/t/s/q` and `<Enter>` only on their own buffers. Existing default mappings remain unchanged.

This avoids turning artifact navigation into global editor behavior and preserves the setup API.

### Treat archived and active changes as separate scopes

Archive search and archive detail operate only on archived changes under `openspec/changes/archive`. The existing summary shortcut behavior operates on the selected active change and must not include archived changes in active progress.

### Render archive detail as a read-only summary buffer

The archive detail buffer should show enough context to decide which artifact to open:

- archive date or archived path segment
- change name
- source path
- task progress
- artifact status
- proposal summary
- design decision excerpts
- task checklist excerpt
- spec delta names and first relevant excerpt

The detail view should not duplicate complete artifact bodies; artifact shortcuts remain the escape hatch for source-of-truth reading.

## Risks / Trade-offs

- Archive path formats may vary across OpenSpec versions -> infer archive metadata from file paths defensively and display unknown values instead of failing.
- Query highlighting may be unavailable or hard to make exact for all snippets -> use standard Neovim highlighting when possible and keep plain snippets as the fallback.
- Large archive directories can produce noisy output -> cap archived change results and per-change snippets, and show a refine-query hint when truncated.
- Multiple spec deltas need disambiguation -> use `vim.ui.select` and keep direct open only for the single-spec case.
- Source windows can disappear before a shortcut is used -> validate window handles before opening and fall back to the current window.

## Migration Plan

This is an additive change.

1. Add resolver and buffer-local navigation helpers with tests.
2. Add archive search rendering metadata, key hints, caps, and empty states.
3. Add archive detail view and shortcuts.
4. Add summary buffer artifact metadata and `p/d/t/s` shortcuts.
5. Update README/help text if user-facing commands or hints need documentation.

Rollback is straightforward: remove the new archive navigation/detail modules and shortcut installation while preserving existing summary behavior.

## Open Questions

- Should archive search be implemented as `:OpenSpecArchiveSearch [query]` only, or should a no-query invocation list recent archived changes by default? The current plan assumes no-query listing is useful.
- Should future layout configuration support splits/tabs? This change intentionally avoids layout options to keep the public setup API stable.
