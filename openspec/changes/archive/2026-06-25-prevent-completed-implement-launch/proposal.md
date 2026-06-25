## Why

`OpenSpecImplement` can currently launch an implementation session even when
the selected task is already done or the whole change is already complete. This
can send agents back into implementation when the correct next step is verify
or archive.

## What Changes

- Add a launch guard for completed whole-change implementation requests.
- Add a launch guard for selected task requests when the selected task is
  already `done` or `skipped`.
- Show a clear Neovim notification that explains the blocked launch and the
  recommended next action.
- Keep provider/model/layout resolution unchanged for changes and tasks that
  still have implementation work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `openspec-nvim`: `OpenSpecImplement` launch behavior changes when the target
  change or selected task is already complete.

## Impact

- Affects `:OpenSpecImplement` command behavior.
- Affects `lua/openspec/init.lua` and focused tests around implementation
  launch selection.
- Does not change public setup options, provider adapter configuration, or
  default keymaps.
