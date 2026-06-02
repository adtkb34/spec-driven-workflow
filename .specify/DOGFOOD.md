# Dogfood — 用真实需求端到端验收本工作流

本次「从声称到机制可强制」优化的**最终验收**：拿一个**真实需求**跑完整条流水线，
留下各门退出码与 `verify.md` 证据。**在用户提供真实需求前，本验收保持 pending。**

> 目的不是再写一份文档，而是用工作流自己跑工作流（dogfooding），
> 证明门确实拦得住、能力确实挂得上、verify 确实跑得动。

## 待办（需用户给真实需求后执行）

- [ ] 用户提供一句话真实需求。
- [ ] `/speckit-specify` → 产出 `spec.md`，标注 `[NEEDS CLARIFICATION]`，并定 `complexity`。
- [ ] `/speckit-clarify` → 消除模糊点。
- [ ] **跑 `gate-clarify.sh`** → 记录退出码（应 0）。
- [ ] 技术栈闸门 → 与用户确认方向，写 `FEATURE_DIR/stack.yml`（`confirmed: true`、`form`、能力标志）。
- [ ] **跑 `gate-stack.sh`** → 记录退出码（应 0）。
- [ ] **跑 `activate-dimensions.sh`** → 记录激活的条件维度，核对与栈一致。
- [ ] `/speckit-plan` → `/speckit-tasks`。
- [ ] `/speckit-analyze` + **跑 `gate-analyze.sh`** → 记录退出码（应 0）。
- [ ] `/speckit-implement`。
- [ ] 写 `FEATURE_DIR/verify.yml`（`form` + 启动/测试命令 + `scan_paths`）。
- [ ] **跑 `gate-verify.sh`** → 退出码 0；按 `form` 档位补人工验收项，写 `FEATURE_DIR/verify.md`。

## 证据清单（验收时填写）

| 门 / 步骤 | 命令 | 期望 | 实际退出码 | 证据位置 |
|-----------|------|------|-----------|----------|
| clarify   | `gate-clarify.sh`  | 0 |  |  |
| stack     | `gate-stack.sh`    | 0 |  |  |
| 激活维度  | `activate-dimensions.sh` | 与栈一致 |  |  |
| analyze   | `gate-analyze.sh`  | 0 |  |  |
| verify    | `gate-verify.sh`   | 0 |  | `verify.md` |

## 已完成的结构性自检（优化落地时）

门脚本行为已用合成 fixture 验证通过（不替代真实需求 dogfood）：

- `gate-clarify.sh`：含 `[NEEDS CLARIFICATION]` → exit 1；清除后 → exit 0。
- `gate-stack.sh`：无 `stack.yml` / `confirmed: false` → exit 1；`confirmed: true`+`form` → exit 0。
- `activate-dimensions.sh`：`backend+persistence+cloud=gcp` → `api_design`/`data_modeling`/`gcp_runtime`；
  `frontend+ui` → `frontend_ui`/`ux_design`（无误挂）。
- `gate-analyze.sh`：用户故事缺 task 落点 → exit 1；全覆盖 → exit 0。
- `gate-verify.sh`：命令非零 → exit 1；`scan_paths` 含残留 → exit 1；全绿无残留 → exit 0；按 `form` 选档。
- `registry.yaml`：YAML 合法，全部 `path`/`fallback_path`/`companion_path` 存在（23 维度）。
