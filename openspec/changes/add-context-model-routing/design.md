# Design

## 1. Product Boundary

`OpenSpecContext` remains a markdown handoff generator. Model routing is guidance inside the handoff, not an external-session controller.

```text
OpenSpec task context
  -> artifact / health / git / verification evidence
  -> model routing guidance
  -> downstream human or agent decides how to activate a model profile
```

This keeps `openspec.nvim` provider-neutral and avoids duplicating lifecycle automation already owned by upstream OpenSpec flows.

## 2. Configuration Shape

Add `context.model_routing` to setup options:

- `enabled`: controls whether the section is rendered.
- `profiles`: ordered list of routing profiles.
  - `name`: display name.
  - `model`: free-form model label.
  - `effort`: free-form reasoning/effort label.
  - `command`: optional copyable activation command or UI hint.
  - `use_for`: concise task category.
- `switch_rules`: ordered list of general switching rules.

The defaults should be provider-neutral:

- Planning/spec profile for proposal, design, task, and spec decisions.
- Implementation profile for code, test, and documentation edits.
- Verification/audit profile for checks, failures, and ambiguity review.

Users who want OpenAI-specific routing can configure strings such as `gpt-5.5 / xhigh` for planning and `gpt-5.4 / high` for implementation without the plugin needing to understand the provider.

## 3. Context Output

The generated context pack adds a `## Model Routing` section before local health findings.

The section should:

- state that the section is guidance only;
- list ordered model profiles;
- include optional activation commands when configured;
- include switch rules that tell downstream agents when to move between planning and implementation profiles.

## 4. Validation Criteria

- Context pack output includes default model routing guidance.
- Custom setup options appear in the generated context pack.
- Disabling `context.model_routing.enabled` omits the section.
- `make check` passes.
- `openspec validate --all --strict` passes.
