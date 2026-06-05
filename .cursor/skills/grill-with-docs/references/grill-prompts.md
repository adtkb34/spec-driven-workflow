# Grill Prompts by Form

Optional checklists when `stack.yml` → `form` is set.

## web / desktop

- UI state: loading / error / empty — specified in plan or explicitly waived?
- Auth/session boundaries match spec roles?
- No `window.prompt` / native dialogs if desktop WebView (constitution)?

## service / api

- Idempotency and error contracts documented?
- Versioning / breaking change policy stated?

## cli

- Exit codes and stderr vs stdout contract?
- Config precedence (env > file > flags)?

## library

- Public API surface vs internal modules?
- Semver / breaking change policy?

## pipeline

- Failure modes and retry/idempotency?
- Observability hooks (logs/metrics) in plan?

## All forms

- Terms in plan match CONTEXT.md or glossary updated?
- Out-of-scope items in charter still out-of-scope in plan?
- No silent tech stack drift vs `stack.yml`?
