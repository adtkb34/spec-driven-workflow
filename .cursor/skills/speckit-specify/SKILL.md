---
name: "speckit-specify"
description: "Create or update the feature specification from a natural language feature description."
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/specify.md"
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before specification)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_specify` key
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

## Phase Entry (P0 → P2 → P1 · specify)

Before Outline:

1. Run `.specify/scripts/bash/phase-brief.sh --phase specify` (resume: `--questions-only`).
2. Self-answer P0 questions from `phase-index.yml` (questions only, no rule dump).
3. **full ceremony**: 5-line opening (phase, FEATURE_DIR, unlock/gates, model tier, next step) → **wait for user「继续」** before reading this SKILL body (if not already loaded).
4. **硬序① — Charter upstream**：`charter.md` + `charter.yml` 须已 `confirmed: true` 且 `gate-charter.sh` PASS（见 phase-brief unlock；**不在 specify gates 重复登记**）。Read 已确认 charter，**不得改写** charter 已批大方向。
5. **硬序② — Context Isolation Gate**（见下节）：写 `global-prefs.yml`（`confirmed: true`）。可与 spec 追问同轮，**不得跳过**。
6. Run P2 gates as needed; `phase-brief.sh --unlock-status` for live status (not cached in phase.yml).
7. **After P2 pass** → `activate-dimensions.sh --phase specify` → inject D1 summaries only.
8. End with `run-log.sh phase --phase specify ...`（`--scripts` 须含 `gate-global-prefs.sh` 与 `gate-spec-coverage.sh`）。Orchestration: `triage-fast-track.md`, `enhancement-layer.md`.

## Outline

The text the user typed after `/speckit-specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

## Context Isolation Gate (环境隔离闸门 · specify 硬序② · 必做)

在 **从 charter 扩写 spec 之前**完成（详见 `enhancement-layer.md`），防止全局偏好污染本工作流:

- 检测并向用户列出可能生效的全局偏好来源（Cursor User/Team Rules、`AGENTS.md`、Cursor/Copilot Memories）。
- 一次确认本特性如何处理：**ignore（默认隔离）/ selective / adopt**；默认 `ignore`，不替用户决定。
- **落盘**（建特性目录时 `create-new-feature.sh` 会种子模板；否则 `cp .specify/templates/global-prefs-template.yml`）：
  - `FEATURE_DIR/global-prefs.yml`：`decision` + `confirmed: true` +（selective 时）`global_prefs_allow`
  - 若已有 `stack.yml`，同步 `global_prefs` / `global_prefs_allow` 与上一致
- specify 结束前须 `gate-global-prefs.sh` PASS。
- 任何档位下，全局偏好都**不得**覆盖阶段门 / constitution / 维度 skill / verify DoD。

## Charter upstream (已确认 · 只读)

**`FEATURE_DIR/charter.md` 须在 `/speckit-charter` 阶段经用户确认。** specify 从 charter 扩写 spec，不重复 abc 补齐（已迁到 charter）。

1. Read `charter.md` + `charter.yml`；`## Background & Goals` 写 **3–5 句摘要 + 链接** `charter.md`，不复制全文。
2. User Stories / FR / Input Q&A / Post-Draft Ping 逻辑不变；**首条不问卷 ②③④⑤**（未提到则留 Ping）。
3. 若发现与 charter 冲突，**先改 charter（回 /speckit-charter）**，不得在 spec 静默扩 scope。
4. **Brainstorming（specify 限定）**：abc 已在 charter 完成；**仅**当用户要求扩 scope 或与 charter 冲突需重新对齐时，激活 `requirements`（brainstorming）— 一次一问或回 charter；**禁止**在 specify 重做 abc 或跑 `partial_approaches` / `writing-plans`。
5. **第一性原理**：把用户功能点当待验证假设；未确认项用 `[NEEDS CLARIFICATION]` 或 Assumptions 标签。

Given that feature description and confirmed charter, do this:

1. **Generate a concise short name** (2-4 words) for the feature:
   - Analyze the feature description and extract the most meaningful keywords
   - Create a 2-4 word short name that captures the essence of the feature
   - Use action-noun format when possible (e.g., "add-user-auth", "fix-payment-bug")
   - Preserve technical terms and acronyms (OAuth2, API, JWT, etc.)
   - Keep it concise but descriptive enough to understand the feature at a glance
   - Examples:
     - "I want to add user authentication" → "user-auth"
     - "Implement OAuth2 integration for the API" → "oauth2-api-integration"
     - "Create a dashboard for analytics" → "analytics-dashboard"
     - "Fix payment processing timeout bug" → "fix-payment-timeout"

2. **Branch creation** (optional, via hook):

   If a `before_specify` hook ran successfully in the Pre-Execution Checks above, it will have created/switched to a git branch and output JSON containing `BRANCH_NAME` and `FEATURE_NUM`. Note these values for reference, but the branch name does **not** dictate the spec directory name.

   If the user explicitly provided `GIT_BRANCH_NAME`, pass it through to the hook so the branch script uses the exact value as the branch name (bypassing all prefix/suffix generation).

3. **Create the spec feature directory**:

   Specs live under the default `specs/` directory unless the user explicitly provides `SPECIFY_FEATURE_DIRECTORY`.

   **Resolution order for `SPECIFY_FEATURE_DIRECTORY`**:
   1. If the user explicitly provided `SPECIFY_FEATURE_DIRECTORY` (e.g., via environment variable, argument, or configuration), use it as-is
   2. Otherwise, auto-generate it under `specs/`:
      - Check `.specify/init-options.json` for `branch_numbering`
      - If `"timestamp"`: prefix is `YYYYMMDD-HHMMSS` (current timestamp)
      - If `"sequential"` or absent: prefix is `NNN` (next available 3-digit number after scanning existing directories in `specs/`)
      - Construct the directory name: `<prefix>-<short-name>` (e.g., `003-user-auth` or `20260319-143022-user-auth`)
      - Set `SPECIFY_FEATURE_DIRECTORY` to `specs/<directory-name>`

   **Create the directory and spec file**:
   - `mkdir -p SPECIFY_FEATURE_DIRECTORY`
   - Copy `.specify/templates/global-prefs-template.yml` to `SPECIFY_FEATURE_DIRECTORY/global-prefs.yml` if missing; set `decision` + `confirmed: true` per hard-order ① (or run `create-new-feature.sh` which seeds it)
   - Copy `.specify/templates/spec-template.md` to `SPECIFY_FEATURE_DIRECTORY/spec.md` as the starting point
   - Set `SPEC_FILE` to `SPECIFY_FEATURE_DIRECTORY/spec.md`
   - Persist the resolved path to `.specify/feature.json`:
     ```json
     {
       "feature_directory": "<resolved feature dir>"
     }
     ```
     Write the actual resolved directory path value (for example, `specs/003-user-auth`), not the literal string `SPECIFY_FEATURE_DIRECTORY`.
     This allows downstream commands (`/speckit-plan`, `/speckit-tasks`, etc.) to locate the feature directory without relying on git branch name conventions.

   **IMPORTANT**:
   - You must only create one feature per `/speckit-specify` invocation
   - The spec directory name and the git branch name are independent — they may be the same but that is the user's choice
   - The spec directory and file are always created by this command, never by the hook

4. Load `.specify/templates/spec-template.md` to understand required sections.

5. **IF EXISTS**: Load `.specify/memory/constitution.md` for project principles and governance constraints.

6. Follow this execution flow:
    1. Parse user description from arguments
       If empty: ERROR "No feature description provided"
    2. Extract key concepts from description
       Identify: actors, actions, data, constraints
    3. For unclear aspects (**前提：charter 已 confirmed 且 gate-charter PASS**；背景/目标缺口应回 charter，不得在本步靠猜填空):
       - Make informed guesses based on context and industry standards **only for low-impact details** (e.g. data retention, error-message wording). 对涉及背景/目标/成功标准/核心范围的缺口，回 `/speckit-charter` 或按 §Brainstorming（specify 限定）对齐，禁止用行业常识猜满。
       - Only mark with [NEEDS CLARIFICATION: specific question] if:
         - The choice significantly impacts feature scope or user experience
         - Multiple reasonable interpretations exist with different implications
         - No reasonable default exists
       - **LIMIT: Maximum 3 [NEEDS CLARIFICATION] markers total**
       - Prioritize clarifications by impact: scope > security/privacy > user experience > technical details
    4. Fill User Scenarios & Testing section
       If no clear user flow: ERROR "Cannot determine user scenarios"
    5. Generate Functional Requirements
       Each requirement must be testable
       Use reasonable defaults for unspecified details (document assumptions in Assumptions section)
    6. Define Success Criteria
       Create measurable, technology-agnostic outcomes
       Include both quantitative metrics (time, performance, volume) and qualitative measures (user satisfaction, task completion)
       Each criterion must be verifiable without implementation details
    7. Identify Key Entities (if data involved)
    8. Return: SUCCESS (spec ready for planning)

6. Write the specification to SPEC_FILE using the template structure, replacing placeholders with concrete details derived from the feature description (arguments) while preserving section order and headings.

7. **Specification Quality Validation**: After writing the initial spec, validate it against quality criteria:

   a. **Create Spec Quality Checklist**: Generate a checklist file at `SPECIFY_FEATURE_DIRECTORY/checklists/requirements.md` using the checklist template structure with these validation items:

      ```markdown
      # Specification Quality Checklist: [FEATURE NAME]
      
      **Purpose**: Validate specification completeness and quality before proceeding to planning
      **Created**: [DATE]
      **Feature**: [Link to spec.md]
      
      ## Content Quality
      
      - [ ] No implementation details (languages, frameworks, APIs)
      - [ ] Focused on user value and business needs
      - [ ] Written for non-technical stakeholders
      - [ ] All mandatory sections completed
      
      ## Requirement Completeness
      
      - [ ] No [NEEDS CLARIFICATION] markers remain
      - [ ] Requirements are testable and unambiguous
      - [ ] Success criteria are measurable
      - [ ] Success criteria are technology-agnostic (no implementation details)
      - [ ] All acceptance scenarios are defined
      - [ ] Edge cases are identified
      - [ ] Scope is clearly bounded
      - [ ] Dependencies and assumptions identified
      
      ## Feature Readiness
      
      - [ ] All functional requirements have clear acceptance criteria
      - [ ] User scenarios cover primary flows
      - [ ] Feature meets measurable outcomes defined in Success Criteria
      - [ ] No implementation details leak into specification
      
      ## Notes
      
      - Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
      ```

   b. **Run Validation Check**: Review the spec against each checklist item:
      - For each item, determine if it passes or fails
      - Document specific issues found (quote relevant spec sections)

   c. **Handle Validation Results**:

      - **If all items pass**: Mark checklist complete and proceed to the Mandatory Post-Execution Hooks section

      - **If items fail (excluding [NEEDS CLARIFICATION])**:
        1. List the failing items and specific issues
        2. Update the spec to address each issue
        3. Re-run validation until all items pass (max 3 iterations)
        4. If still failing after 3 iterations, document remaining issues in checklist notes and warn user

      - **If [NEEDS CLARIFICATION] markers remain**:
        1. Extract all [NEEDS CLARIFICATION: ...] markers from the spec
        2. **LIMIT CHECK**: If more than 3 markers exist, keep only the 3 most critical (by scope/security/UX impact). **超出 3 个的部分禁止 silent 默认句**——须标为 `[ASSUMPTION: …]` 写入 Assumptions，或继续 clarify 直至用户确认；不得用「行业常识猜满」替代。
        3. For each clarification needed (max 3), present options to user in this format:

           ```markdown
           ## Question [N]: [Topic]
           
           **Context**: [Quote relevant spec section]
           
           **What we need to know**: [Specific question from NEEDS CLARIFICATION marker]
           
           **Suggested Answers** (按推荐度从高到低排序,置顶 = 最推荐):
           
           | Option | 推荐度 | 依据来源 | Answer | Implications |
           |--------|--------|----------|--------|--------------|
           | A      | ★★★ | [最佳实践] | [Most recommended answer] | [What this means for the feature] |
           | B      | ★★ | [行业标准] | [Second answer] | [What this means + its trade-off] |
           | C      | ★ | [Opus 领域知识] | [Fallback answer] | [What this means + why not preferred] |
           | Custom | — | — | Provide your own answer | [Explain how to provide custom input] |
           
           推荐度: `★★★` 首选 / `★★` 可选(有代价) / `★` 备选(兜底)。**行必须按推荐度从高到低排,不得把弱选项放在强选项之上。**
           依据来源(强制,除 Custom 行外不得为空,取自受控词表): `[最佳实践]`/`[行业标准]`/`[constitution]`/`[spec 约束]`/`[skill:<名>]`/`[既有栈/约定]`/`[Opus 领域知识]`(诚实兜底,不得伪装成最佳实践)。
           
           **Your choice**: _[Wait for user response]_
           ```

        4. **CRITICAL - Table Formatting**: Ensure markdown tables are properly formatted:
           - Use consistent spacing with pipes aligned
           - Each cell should have spaces around content: `| Content |` not `|Content|`
           - Header separator must have at least 3 dashes: `|--------|`
           - Test that the table renders correctly in markdown preview
        5. Number questions sequentially (Q1, Q2, Q3 - max 3 total)
        6. Present all questions together before waiting for responses
        7. Wait for user to respond with their choices for all questions (e.g., "Q1: A, Q2: Custom - [details], Q3: B")
        8. Update the spec by replacing each [NEEDS CLARIFICATION] marker with the user's selected or provided answer
        9. Re-run validation after all clarifications are resolved

   d. **Update Checklist**: After each validation iteration, update the checklist file with current pass/fail status

## Post-Draft Coverage Ping（spec v0 后 · `run-log` 前必做）

**在 spec v0 写入磁盘后、Mandatory Post-Execution Hooks / run-log 之前执行。** 先起草再补问，不框死首条。

### 1. 内部覆盖打标

扫描 spec v0 + 对话，对五维打标：`Covered | Partial | Missing | Waived`（内部 map）。向用户输出 **≤8 行覆盖摘要**（表格或列表）。

### 2. 补问范围（一次一维 · 对话 + 落盘）

- **本阶段只补 ② ③**（缺口且影响进 clarify 时）；**④ 不在此逐条问**（clarify 主战场）；**⑤ 不在此问 To-Be 技术栈**（plan 前 stack gate）。
- **standard/complex**：② 或 ③ 为 Missing 且无 Waived → **最多各补 1 问**。
- **trivial**：可压缩；若无 ② 且无 legacy 迹象 → 记 waived Q→A，不追问。

### 3. 对话展示格式（硬约束）

提问：`**【② 现状 As-Is】问：** …`（③ 用 **【③ 基线功能需求】**）。用户答后复述：`**【② …】答：** …`

### 4. spec 落盘（与正文同步）

每条 Q→A 写入 `## Input Q&A (②③④⑤)` 对应小节：`- **Q:** … **A:** … _(specify ping, YYYY-MM-DD)_`；并更新 `Current State (As-Is)` / Stories / Assumptions。跳过 → `A: waived（…）` 仍记一条。

**trivial 且无补问**：仍写 `- **Q:** 有无 As-Is/候选/环境材料？ **A:** 无，按 trivial 跳过 _(waived)_`。

### 5. spec-coverage.yml 落盘（机械门数据源）

Ping 结束后**必须**在 `FEATURE_DIR/spec-coverage.yml` 写入覆盖度（从 `.specify/templates/spec-coverage-template.yml` 复制并填实）：

- `ping_completed_at`：ISO8601 时间戳
- `complexity`：与 `stack.yml` 一致（若尚无 stack 则按 triage 档位）
- `dimensions`：五维 `status`（`background` 须 `covered`；②③ `covered|waived|partial`；④ `deferred_clarify`；⑤ `deferred_stack_gate`）；`waived` **必须**有 `note`，且与 spec Input Q&A 对应 **A:** 一致
- `input_qa_count`：各 `### ②`…`⑤` 下 `- **Q:**` 行数（与 spec 对齐，允许 ±0）

**未完成 Ping / 未写 spec-coverage.yml 时**：不得宣称 specify 完成；`gate-spec-coverage.sh` 会 BLOCK。

### 6. Assumptions 标签（standard/complex）

`## Assumptions` 每条 bullet **必须**以 `[ASSUMPTION]` 或 `[CONFIRMED]` 开头：

- 非用户原话、非 Input Q&A / Ping 已确认 → `[ASSUMPTION] …`
- 用户 Ping/clarify 已确认 → `[CONFIRMED] …`

trivial 可省略标签（门不检）。

### 7. run-log

`run-log.sh phase --phase specify` 的 `--scripts` 须含 **`gate-spec-coverage.sh`**（若 Ping 刚完成则自跑门，退出码即真相）。

**Ping 未完成（仍有 Missing ②③ 且用户未 waived）时**：不得宣称 specify 完成或进入 clarify。

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_specify`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_specify` key.
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

Report completion to the user with:
- `SPECIFY_FEATURE_DIRECTORY` — the feature directory path
- `SPEC_FILE` — the spec file path
- Checklist results summary
- Readiness for the next phase (`/speckit-clarify` or `/speckit-plan`)

**NOTE:** Branch creation is handled by the `before_specify` hook (git extension). Spec directory and file creation are always handled by this core command.

## Quick Guidelines

- Focus on **WHAT** users need and **WHY**.
- Avoid HOW to implement (no tech stack, APIs, code structure).
- Written for business stakeholders, not developers.
- DO NOT create any checklists that are embedded in the spec. That will be a separate command.

### Section Requirements

- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation

When creating this spec from a confirmed charter (**charter 已 gate-charter PASS**；abc 缺口回 charter，不要在 specify 补背景):

1. **Make informed guesses (低影响细节 only)**: Use context, industry standards, and common patterns to fill **low-impact** gaps. 背景/动机/目标/成功标准/核心范围属于高影响项，不靠猜——回 charter 或按 §Brainstorming（specify 限定）对齐。
2. **Document assumptions**: 每条 Assumptions 以 `[ASSUMPTION]` 或 `[CONFIRMED]` 前缀标注来源（见 Post-Draft §6）
3. **Limit clarifications**: Maximum 3 [NEEDS CLARIFICATION] markers - use only for critical decisions that:
   - Significantly impact feature scope or user experience
   - Have multiple reasonable interpretations with different implications
   - Lack any reasonable default
4. **Prioritize clarifications**: scope > security/privacy > user experience > technical details
5. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
6. **Common areas needing clarification** (only if no reasonable default exists):
   - Feature scope and boundaries (include/exclude specific use cases)
   - User types and permissions (if multiple conflicting interpretations possible)
   - Security/compliance requirements (when legally/financially significant)

**Examples of reasonable defaults** (don't ask about these):

- Data retention: Industry-standard practices for the domain
- Performance targets: Standard web/mobile app expectations unless specified
- Error handling: User-friendly messages with appropriate fallbacks
- Authentication method: Standard session-based or OAuth2 for web apps
- Integration patterns: Use project-appropriate patterns (REST/GraphQL for web services, function calls for libraries, CLI args for tools, etc.)

### Success Criteria Guidelines

Success criteria must be:

1. **Measurable**: Include specific metrics (time, percentage, count, rate)
2. **Technology-agnostic**: No mention of frameworks, languages, databases, or tools
3. **User-focused**: Describe outcomes from user/business perspective, not system internals
4. **Verifiable**: Can be tested/validated without knowing implementation details

**Good examples**:

- "Users can complete checkout in under 3 minutes"
- "System supports 10,000 concurrent users"
- "95% of searches return results in under 1 second"
- "Task completion rate improves by 40%"

**Bad examples** (implementation-focused):

- "API response time is under 200ms" (too technical, use "Users see results instantly")
- "Database can handle 1000 TPS" (implementation detail, use user-facing metric)
- "React components render efficiently" (framework-specific)
- "Redis cache hit rate above 80%" (technology-specific)

## Done When

- [ ] Specification written to `SPEC_FILE` and validated against quality checklist
- [ ] Extension hooks dispatched or skipped according to the rules in Mandatory Post-Execution Hooks above
- [ ] Completion reported to user with feature directory, spec file path, and checklist results
