---
name: speckit-grill-docs
description: "Alias for grill-with-docs inside /speckit-plan hard order (not a separate pipeline phase). Triggers adversarial review of spec/plan/CONTEXT/ADR."
---

# Grill Docs (Speckit alias)

User invoked `/grill-docs` or equivalent. **Not** a standalone P1 phase.

## Required flow

1. Confirm `plan.md` draft exists and upstream gates passed (`gate-clarify`, `gate-stack`).
2. Follow [grill-with-docs/SKILL.md](../grill-with-docs/SKILL.md) end-to-end.
3. Run `gate-grill.sh` — must PASS before claiming plan complete.
4. Return control to [speckit-plan/SKILL.md](../speckit-plan/SKILL.md) Completion Report.

Do not skip `grill-log.md` / `grill.yml` on standard/complex features.
