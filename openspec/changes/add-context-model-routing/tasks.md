# Plan

- [x] 1. Specification
  - [x] 1.1 Add model routing requirement delta for context packs.
  - [x] 1.2 Keep provider-neutral wording and lifecycle boundary explicit.

- [x] 2. Implementation
  - [x] 2.1 Add `context.model_routing` defaults to config.
  - [x] 2.2 Render a `Model Routing` section in `:OpenSpecContext`.
  - [x] 2.3 Support custom profiles, commands, switch rules, and disabled state.

- [x] 3. Documentation and tests
  - [x] 3.1 Cover default and custom routing output in context tests.
  - [x] 3.2 Document setup configuration in README.
  - [x] 3.3 Run `make check`.
  - [x] 3.4 Run `openspec validate --all --strict`.
