# Dogfood — 用真实需求端到端验收本工作流

本次「从声称到机制可强制」优化的**最终验收**：拿一个**真实需求**跑完整条流水线，
留下各门退出码与 `verify.md` 证据。**在用户提供真实需求前，本验收保持 pending。**

> 目的不是再写一份文档，而是用工作流自己跑工作流（dogfooding），
> 证明门确实拦得住、能力确实挂得上、verify 确实跑得动。

## 待办（需用户给真实需求后执行）

- [x] 用户提供一句话真实需求。→「做一个记事本」
- [x] `/speckit-specify` → `specs/002-markdown-notes-desktop/spec.md`，无 `[NEEDS CLARIFICATION]`，`complexity: standard`。
- [x] 需求挖掘（brainstorming 等价 clarify）→ 7 问后起草。
- [x] **跑 `gate-clarify.sh`** → 0（见 run-log）。
- [x] 技术栈闸门 → Tauri 2 + React + SQLite，`stack.yml` `confirmed: true`。
- [x] **跑 `gate-stack.sh`** → 0。
- [x] **跑 `activate-dimensions.sh`** → `frontend_ui`, `data_modeling`。
- [x] `/speckit-plan` → `/speckit-tasks`。
- [x] `/speckit-analyze` + **跑 `gate-analyze.sh`** → 0。
- [x] `/speckit-implement` → `apps/notes-desktop/`。
- [x] 写 `verify.yml` + **跑 `gate-verify.sh`** → 0。
- [ ] **GUI 验收表** `verify.md` US1–US5 全部勾选（机械测试已过，界面场景待人工）。

**自动评分**: [`specs/002-markdown-notes-desktop/dogfood-score.md`](../specs/002-markdown-notes-desktop/dogfood-score.md) — **4.2/5（B+）**

## 证据清单（验收时填写）

| 门 / 步骤 | 命令 | 期望 | 实际退出码 | 证据位置 |
|-----------|------|------|-----------|----------|
| clarify   | `gate-clarify.sh`  | 0 | 0 | `specs/002-…/run-log.md` |
| stack     | `gate-stack.sh`    | 0 | 0 | 同上 |
| 激活维度  | `activate-dimensions.sh` | 与栈一致 | frontend_ui, data_modeling | plan 阶段记录 |
| analyze   | `gate-analyze.sh`  | 0 | 0 | 同上 |
| verify    | `gate-verify.sh`   | 0 | 0 | `verify.md`, `dogfood-score.md` |

## 防复发补丁（2026-06-03 · 笔记 App 事故后）

| 机制 | 作用 |
|------|------|
| `verify-profiles.md` · **desktop** 档 | GUI 真启动 + 禁 `window.prompt` |
| `gate-stack.sh` | `ui:true` 或 Tauri/Electron 时 **BLOCK `form:cli`** |
| `sync-verify.sh` | spec/tasks → `verify-coverage.yml` + 合并 `verify.yml` |
| `gate-verify.sh` | sync + 跑命令 + 对齐检查 + 拦「待跑」；扫 `window.prompt` |
| `speckit-plan` / `speckit-implement` | 顺序：先 GUI 验收写 verify.md → 再 gate |
| `verify-template.md` | 验收表模板，禁止「待 GUI」占位 |

详见 `specs/002-markdown-notes-desktop/workflow-gaps.md`。

## 已完成的结构性自检（优化落地时）

门脚本行为已用合成 fixture 验证通过（不替代真实需求 dogfood）：

- `gate-clarify.sh`：含 `[NEEDS CLARIFICATION]` → exit 1；清除后 → exit 0。
- `gate-stack.sh`：无 `stack.yml` / `confirmed: false` → exit 1；`confirmed: true`+`form` → exit 0。
- `activate-dimensions.sh`：`backend+persistence+cloud=gcp` → `api_design`/`data_modeling`/`gcp_runtime`；
  `frontend+ui` → `frontend_ui`/`ux_design`（无误挂）。
- `gate-analyze.sh`：用户故事缺 task 落点 → exit 1；全覆盖 → exit 0。
- `gate-verify.sh`：命令非零 → exit 1；`scan_paths` 含残留 → exit 1；全绿无残留 → exit 0；按 `form` 选档。
- `registry.yaml`：YAML 合法，全部 `path`/`fallback_path`/`companion_path` 存在（23 维度）。
