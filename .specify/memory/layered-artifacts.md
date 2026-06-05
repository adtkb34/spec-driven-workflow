# Layered specs artifacts contract

Version: 1 (aligns with `.specify/feature.json` v3)

## Product model

| Level | Path | Entry file |
|-------|------|------------|
| Module | `specs/<module>/` | `README.md` |
| Charter | `charters/<slug>/` | `charter.md` |
| Spec dimension | `specs/<dimension>/` | `spec.md` |
| Plan | `plans/<slug>/` | `plan.md` |
| Task set | `tasks/<slug>/` | `tasks.md` |

Relationships: 1 module → N charters → N spec dimensions → N plans → N task sets.

## Sharding rules

1. **One index per work unit** — keep index ≤ ~80 lines.
2. **Split when** a topic exceeds ~40 lines or ≥5 parallel items.
3. **Details** live under `docs/` (or `plans/<slug>/docs/`) with semantic filenames.
4. **Register** paths in `*-manifest.yml` under `shards:` (globs allowed).

## Shared content (`shared/`)

| Scope | Path |
|-------|------|
| Cross-charter | `specs/<module>/shared/` |
| Cross spec/plan within charter | `charters/<charter>/shared/` |
| Spec-dimension `shared/` | **Discouraged** — float up to charter |

Rules:

- Two or more siblings need the same text → move to parent `shared/`.
- Indexes link only; do not duplicate body text.
- Declare dependencies in manifest `includes.module` / `includes.charter` (paths relative to those roots).

## Manifest schema (`*-manifest.yml`)

```yaml
version: 1
index: spec.md          # or plan.md
includes:
  module: []
  charter: []
shards:
  key: path/or/glob
read_scope:
  specify: []           # phase keys as needed
gate_aggregate_extra: [] # optional; see aggregation
```

## Pinned rules (gates & tools)

### 1. Gate aggregation

`aggregate-spec-text.sh` default:

```text
aggregate = index + expand(includes.*) + expand(shards.*) + gate_aggregate_extra
```

Do not duplicate includes/shards paths in `gate_aggregate_extra`.

### 2. State file ownership

| File | Location |
|------|----------|
| `stack.yml`, workflow `phase.yml`, `global-prefs.yml`, `spec-coverage.yml` | `SPEC_DIM_DIR` |
| implement `phase.yml` | `TASK_DIR` |
| `verify.md`, `deliver.md` | `PLAN_DIR` (`active_plan`) |

Verify/deliver WORK_ROOT: `PLAN_DIR` only.

### 3. Manifest validation

`validate-manifest.sh` checks paths exist, no duplicate `gate_aggregate_extra`, optional index link check.

### 4. Spec dimension boundaries

- **functional**: stories, behavior, FR, acceptance
- **data**: schema, mappings, migrations
- **api**: contracts, errors, versioning
- **ux**: wireframes, interaction

Domain model defaults to `charters/<c>/shared/domain-model.md`.

### 5. Migration

First land `docs/legacy-spec-body.md` + minimal manifest; split shards later.

## feature.json v3

```json
{
  "version": 3,
  "module": "<slug>",
  "charter": "<slug>",
  "spec_dimension": "functional",
  "plan": "<slug>",
  "task_set": "<slug>",
  "work_root": "<path to deepest active node>",
  "feature_directory": "<SPEC_DIM_DIR relative to repo root>"
}
```

## Path variables (`common.sh`)

`MODULE_DIR`, `CHARTER_DIR`, `CHARTER_SPEC`, `SPEC_DIM_DIR`, `FEATURE_SPEC`, `PLAN_DIR`, `IMPL_PLAN`, `TASK_DIR`, `TASKS`, `WORK_ROOT`.

`FEATURE_DIR` is always the **spec dimension** directory (`SPEC_DIM_DIR`). Flat `specs/NNN-name/` trees are **not** supported — use `migrate-specs-layout.sh` once, then only layered paths.
