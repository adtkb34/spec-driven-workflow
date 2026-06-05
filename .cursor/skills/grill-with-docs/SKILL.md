---
name: grill-with-docs
description: "Adversarial document review of spec.md, plan.md, CONTEXT.md, and ADRs before analyze. Use after plan draft in Speckit; complements clarify (cooperative) and doubt-driven-development (code decisions)."
aliases:
  - grill-docs
---

# Grill with Docs

Document-level **adversarial** review: find contradictions, undefined terms, ADR conflicts, and scope leaks across artifacts. Not cooperative clarification (that's `/speckit-clarify`); not code CLAIM→DOUBT (that's `doubt-driven-development`).

## When to Use (Speckit)

- **Primary**: After `plan.md` initial draft in `/speckit-plan` (hard order before `gate-grill.sh`).
- **Secondary**: `/speckit-analyze` opening — re-check grill findings still hold.
- **Optional alias**: User may say `/grill-docs`; still runs under plan hard order, not a separate P1 phase.

**When NOT to use:**

- Charter business sign-off (`/speckit-charter`) — business-readable, not ADR/plan grilling.
- trivial features — set `grill.yml` → `waived: true` with one-line reason; `gate-grill.sh` PASS.

## Inputs

Read (minimal necessary):

- `FEATURE_DIR/spec.md`
- `FEATURE_DIR/plan.md`
- Repo `CONTEXT.md` if present (see [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md))
- `docs/decisions/*.md` or `docs/adr/*.md` ADRs if present (see [ADR-FORMAT.md](ADR-FORMAT.md))

## Process

1. **Extract claims** from plan + spec (scope, interfaces, data model, non-goals).
2. **Cross-examine** against CONTEXT terms, existing ADRs, charter scope, and spec FR/US alignment.
3. **Emit findings** to `FEATURE_DIR/grill-log.md` using the table format below.
4. **Resolve loop** (with user when needed):
   - Fix `plan.md` / `spec.md` inline for accepted findings.
   - Offer ADR when rejection reason is load-bearing (see ADR-FORMAT).
   - Update CONTEXT.md when a domain term is sharpened or introduced.
5. **Close findings**: every row must be `RESOLVED` or `WAIVED` (not `OPEN`) before `grill.yml` → `confirmed: true`.
6. Run `gate-grill.sh` (must PASS).

## grill-log.md Format

```markdown
# Grill Log

**Feature**: [name]
**Reviewed**: [ISO8601]

## Findings

| ID | Status | Source | Finding | Resolution |
|----|--------|--------|---------|------------|
| G1 | RESOLVED | plan.md §X | ... | Updated plan.md ... |
| G2 | WAIVED | spec.md | ... | User accepted risk: ... |
```

**Status values**: `OPEN` | `RESOLVED` | `WAIVED` — gate blocks on any `OPEN`.

## Stop Conditions

- No `OPEN` findings remain, OR user explicitly waives remaining items with documented rationale.
- Maximum **2** grill rounds per plan revision; escalate scope conflicts to charter/spec clarify.

## Speckit Prohibitions

- Do not replace `gate-analyze.sh` or `gate-clarify.sh`.
- Do not modify `tasks.md` (analyze is read-only for artifacts).
- Do not skip `grill.yml` on standard/complex.

## References

- [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md)
- [ADR-FORMAT.md](ADR-FORMAT.md)
- [references/grill-prompts.md](references/grill-prompts.md) — optional checklists by `stack.form`
