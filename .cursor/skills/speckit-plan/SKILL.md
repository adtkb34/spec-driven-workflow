---
name: "speckit-plan"
description: "Execute the implementation planning workflow using the plan template to generate design artifacts."
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/plan.md"
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before planning)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_plan` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Workflow Gates (本工作流硬约束 · 退出码即真相)

**进入正文前必须先过门，非零退出即停，先于任何主观判断：**

1. **clarify 门**：运行 `.specify/scripts/bash/gate-clarify.sh`。非零 → 停，回 `/speckit-clarify` 消除残留 `[NEEDS CLARIFICATION]`/TODO 后重跑。
2. **技术栈闸门**：与用户确认技术栈/架构方向（见 constitution「技术栈与运行方式闸门」），把结论写入 `FEATURE_DIR/stack.yml`（可从 `.specify/templates/stack-template.yml` 起手），填 `form` / 能力标志 / `complexity`，并设 `confirmed: true`。
3. **stack 门**：运行 `.specify/scripts/bash/gate-stack.sh`。非零 → 停，补齐 `stack.yml`。
4. **激活条件维度**：运行 `.specify/scripts/bash/activate-dimensions.sh --phase plan`，按输出挂载条件维度（先 L1 summary，按需 L2，见编排规则「渐进披露协议」）。

## Outline

1. **Setup**: Run `.specify/scripts/bash/setup-plan.sh --json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_plan`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_plan` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue to the Completion Report.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Mandatory hook** (`optional: false`) — **You MUST emit `EXECUTE_COMMAND:` for each mandatory hook**:
    ```
    ## Extension Hooks

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```

## Completion Report

Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, and generated artifacts.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Define interface contracts** (if project has external interfaces) → `/contracts/`:
   - Identify what interfaces the project exposes to users or other systems
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, command schemas for CLI tools, endpoints for web services, grammars for parsers, UI contracts for applications
   - Skip if project is purely internal (build scripts, one-off tools, etc.)

3. **Agent context update**:
   - Update the plan reference between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers in `.cursor/rules/specify-rules.mdc` to point to the plan file created in step 1 (the IMPL_PLAN path)

**Output**: data-model.md, /contracts/*, quickstart.md, updated agent context file

## WebView / 桌面栈（plan 必写 · 写入 plan.md「UI/UX 红线」）

技术栈闸门若确认为 **Tauri / Electron / 任何 WebView 壳 + UI**：

1. `stack.yml` 的 `form:` 必须为 **`desktop`**（有窗口 GUI 时**不得**标 `cli`）；纯浏览器页用 `web`。
2. plan.md 必须包含：
   - **禁止** `window.prompt` / `alert` / `confirm`；新建/编辑/删除确认一律**应用内 Dialog**。
   - verify 承诺：真启动 + spec 验收场景逐条实点（写入 `verify.md`，不得留「待跑」）。
3. tasks.md 收尾须含 **GUI 冒烟**（新建主实体 → 编辑 → 重启恢复）。

## Key rules

- Use absolute paths for filesystem operations; use project-relative paths for references in documentation and agent context files
- ERROR on gate failures or unresolved clarifications

## Done When

- [ ] `gate-clarify.sh` 与 `gate-stack.sh` 均 exit 0；`stack.yml` 已写且 `confirmed: true`
- [ ] `activate-dimensions.sh --phase plan` 输出的条件维度已挂载
- [ ] Plan workflow executed and design artifacts generated
- [ ] Extension hooks dispatched or skipped according to the rules in Mandatory Post-Execution Hooks above
- [ ] Completion reported to user with branch, plan path, and generated artifacts
