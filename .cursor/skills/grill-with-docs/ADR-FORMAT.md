# ADR Format (grill-with-docs)

Aligns with `documentation-and-adrs` skill; grill offers ADRs when a **load-bearing** rejection reason should prevent future re-suggestion.

## Location

- Preferred: `docs/decisions/NNNN-short-title.md`
- Alternate: `docs/adr/` if project already uses it

## Template

```markdown
# ADR-0001: [Short title]

**Status**: Accepted | Superseded | Deprecated
**Date**: YYYY-MM-DD

## Context

[What forced the decision]

## Decision

[What we chose]

## Consequences

**Positive**: ...
**Negative**: ...

## Alternatives Considered

- [Option A]: rejected because ...
```

## When grill should offer an ADR

- User rejects a plan direction with a reason future agents would re-litigate.
- Finding conflicts with an existing ADR — update ADR status or add superseding ADR.
- Skip for ephemeral reasons ("not this sprint") or self-evident choices.
