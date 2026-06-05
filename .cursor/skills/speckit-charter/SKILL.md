---
name: "speckit-charter"
description: "Charter the feature before spec: direction, scope, success criteria, and core business logic; user confirms via charter.yml."
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "spec-driven-workflow"
  source: "workflow charter phase"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Phase Entry (P0 → P2 → P1 · charter)

1. Run `.specify/scripts/bash/phase-brief.sh --phase charter` (resume: `--questions-only`).
2. Self-answer P0 questions from `phase-index.yml`.
3. **full ceremony** (trivial → minimal per phase-index): 5-line opening → wait「继续」before main flow.
4. After P2 pass → `activate-dimensions.sh --phase charter` → D1 summaries only.
5. End with `run-log.sh phase --phase charter ...`（`--scripts` 须含 `gate-charter.sh`）。Orchestration: `triage-fast-track.md`.

## Outline

The user's message **is** the feature description. Do not ask them to repeat it unless empty.

**Goal**: Produce a ≤2 page **charter** (business-readable) for user confirmation **before** detailed spec. Do **not** write User Stories, FR-00x, data sources, APIs, or tech stack here.

### 1. Feature directory

Same resolution as speckit-specify: `SPECIFY_FEATURE_DIRECTORY` / `create-new-feature.sh` / `specs/` default. Seed templates if missing:

- `charter.md` from `.specify/templates/charter-template.md`
- `charter.yml` from `.specify/templates/charter-template.yml`

### 2. Triage (complexity)

Assess trivial / standard / complex per `.specify/memory/orchestration/triage-fast-track.md`. Write `charter.yml` → `complexity`. Optionally seed `stack.yml` with `complexity` only (no `confirmed` yet).

**trivial**: compress charter content; ceremony minimal; still require user confirm → `confirmed: true`.

### 3. Background sufficiency (abc · ①)

Before drafting charter, verify (a) background/motivation, (b) goals/success criteria, (c) key constraints.

- **Insufficient** → activate `requirements` (brainstorming skill), mode **`partial_background`** — **one question at a time**; do not draft charter until abc can be written.
- **Sufficient** → continue to §3.5 (if applicable) then draft charter.
- Activate `product_taste` (first-principles) to cut scope / veto derivative work.
- **Visual UI scope** (layout / navigation / style choices at charter grain) → offer `visual-brainstorming` per registry `ux_design` (own message; not combined with abc Q).

### 3.5 Approach trade-offs (`partial_approaches` · standard/complex only)

After abc is sufficient and **before** drafting `charter.md`:

- If `charter.yml` → `complexity` is **standard** or **complex**: activate brainstorming in mode **`partial_approaches`**.
  - Propose **2–3** coarse solution directions (business/outcome level only).
  - State trade-offs and a recommendation; get user pick or hybrid.
  - Record in charter section **`## Approach Trade-offs`** (Chosen / Alternatives rejected / Why).
- If **trivial**: skip (`brainstorming_modes: none` for approaches); omit the section or write `N/A — trivial single-path`.

**Do not** write FR, data sources, APIs, or tech stack in this step.

### 4. Draft `charter.md`

Fill template sections:

- Background & Stakeholders · As-Is Summary · Goals & Success Criteria
- **Approach Trade-offs** (standard/complex; see §3.5)
- In-Scope / Out-of-Scope
- **Core Business Logic** (main flow, business rules, conflict priorities)
- Deferred to Spec / Plan

**Do not** include: FR lists, acceptance scenarios, table/API/field names, implementation.

### 5. User confirmation

Present charter summary (≤8 lines) + full charter path. After explicit user approval:

- Set `charter.yml` → `confirmed: true` + `confirmed_at` (ISO8601)
- Run `gate-charter.sh` (must PASS before claiming charter complete)

### 6. Completion Report

- `FEATURE_DIR`, `charter.md`, `charter.yml`, complexity tier
- Next phase: `/speckit-specify` (spec expands from confirmed charter; do not rewrite charter scope without user)

## Quick Guidelines

- Charter = **what & why** at coarse grain + **domain rules**; spec = testable requirements; plan = how & data.
- One question at a time when clarifying abc; no five-dimension checklist in charter phase.
- If user tries to skip charter on standard/complex, warn that specify will not unlock without `gate-charter` PASS.
