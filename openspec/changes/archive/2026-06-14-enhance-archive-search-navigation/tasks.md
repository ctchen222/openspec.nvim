## 1. Navigation Helpers

- [x] 1.1 Add or extend an artifact target resolver for proposal, design, tasks, and spec delta artifacts.
- [x] 1.2 Add safe artifact opening that prefers the recorded source window and falls back to the current window.
- [x] 1.3 Add buffer-local keymap installation for artifact shortcuts without registering global keymaps.
- [x] 1.4 Add missing-artifact notification behavior that never creates files.

## 2. Archive Search Surface

- [x] 2.1 Implement archived change discovery for `openspec/changes/archive` without including archived changes in active progress discovery.
- [x] 2.2 Render archive search results with a concise key hint for `<Enter>`, `p`, `d`, `t`, `s`, and `q`.
- [x] 2.3 Store archive search line metadata for result detail lines and matched artifact lines.
- [x] 2.4 Implement `<Enter>` behavior for archive detail lines and matched artifact lines.
- [x] 2.5 Implement `p/d/t/s` artifact shortcuts for archived changes.
- [x] 2.6 Group query matches by Proposal, Design, Tasks, and Spec artifact type.
- [x] 2.7 Render match snippets with relative path, line number when known, and concise snippet text.
- [x] 2.8 Highlight query text in snippets when possible.
- [x] 2.9 Add no-archive and no-match empty states.
- [x] 2.10 Cap archive search output to 25 archived changes and 5 snippets per archived change with a refine-query hint when truncated.
- [x] 2.11 Add toggle behavior for `:OpenSpecArchiveSearch` (second invocation closes the view).
- [x] 2.12 Close archive search/detail windows after successful `p/d/t/s` artifact open from archive search/detail.

## 3. Archive Detail Surface

- [x] 3.1 Add a read-only archive detail buffer with filetype `openspec-archive-detail`.
- [x] 3.2 Render archived change name, source path, archive date when known, task progress, and artifact status.
- [x] 3.3 Render concise proposal summary, design excerpts, task checklist excerpt, and spec delta names/excerpts.
- [x] 3.4 Add buffer-local `p/d/t/s/q` shortcuts to archive detail.
- [x] 3.5 Verify archive detail does not expose archive, unarchive, apply, verify, sync, or task-completion actions.

## 4. Summary Artifact Shortcuts

- [x] 4.1 Store selected active change artifact metadata in the summary buffer.
- [x] 4.2 Add a concise summary key hint for `p/d/t/s` artifact navigation.
- [x] 4.3 Add buffer-local `p/d/t/s` shortcuts to open proposal, design, tasks, and spec delta artifacts for the selected active change.
- [x] 4.4 Use `vim.ui.select` when the selected active change has multiple spec delta artifacts.
- [x] 4.5 Preserve existing summary mapping behavior, setup API, and default keymaps.

## 5. Tests and Documentation

- [x] 5.1 Add archive search tests for key hints, line metadata, `<Enter>`, `p/d/t/s`, missing artifacts, caps, grouped matches, highlights, and empty states.
- [x] 5.2 Add archive detail tests for read-only behavior, filetype, displayed metadata/excerpts, shortcuts, and lifecycle-action absence.
- [x] 5.3 Add summary tests for buffer-local `p/d/t/s`, selected active change targets, multi-spec selection, missing artifacts, and no global keymaps.
- [x] 5.4 Add tests for archive search lifecycle (toggle close, closeability after artifact navigation).
- [x] 5.5 Update README or help documentation for archive search and summary artifact shortcuts if the implementation exposes user-facing usage text.
- [x] 5.6 Run `make check`.
- [x] 5.7 Run `openspec validate enhance-archive-search-navigation --strict`.
- [x] 5.8 Run `openspec validate --all --strict`.
