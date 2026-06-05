# CONTEXT.md Format

Repository-level domain vocabulary. Grill-with-docs and improve-codebase-architecture use the same discipline.

## Location

- Preferred: repo root `CONTEXT.md`
- Create lazily on first grill or architecture deepening when a new domain term is named.

## Structure

```markdown
# Project Context

## Domain Glossary

| Term | Definition | Not |
|------|------------|-----|
| Order | Customer purchase request awaiting fulfillment | Not a shipment |

## Bounded Contexts

- **Scheduling**: production slot assignment
- **Inventory**: stock levels and reservations

## Invariants (business)

- An Order cannot be scheduled without a confirmed BOM.
```

## Rules

- Terms used in `plan.md` / `spec.md` must appear here or be added during grill resolution.
- **Not** a dump of file paths or class names — domain language only.
- Updates during grill are inline edits; no separate approval gate beyond grill close-out.
