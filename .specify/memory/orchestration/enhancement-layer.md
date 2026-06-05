# 增强层（Enhancement Layer · 非替换）

注册表里来自 Addy Osmani / Superpowers / Matt Pocock 的维度是**增强**，只 enrich 某阶段子步骤，**不替代** Spec Kit 编排。

1. **冲突裁决优先级**（高 → 低）：
   **Spec Kit 阶段门 > constitution > registry 维度 skill > 外部 skill 默认行为 > 全局偏好**。
2. **硬约束**：外部 skill **不得**覆盖或降低 `verify` 可执行 DoD、技术栈闸门、模型路由。
3. **条件维度激活**：领域维度带 `when:`，**默认休眠**，只在命中条件后激活（`activate-dimensions.sh` 机械判定）。
4. **`source_grounding` vs `grill-with-docs` 分工**：前者 implement 期查框架/库 API；后者 **plan 后、analyze 前**拷问 spec/plan/CONTEXT/ADR（产物 `grill-log.md` + `grill.yml`；`gate-grill.sh` 仅登记在 plan 阶段一次）。与 `doubt-driven-development`（代码/决策 CLAIM→DOUBT）并列，不合并。
5. **`session_handoff`**（meta，仅 `/handoff` 或显式 @ 触发）：OS 临时目录、只指针不复制、不得替代 verify 证据。

## 环境隔离闸门（specify 开场必做 · 硬序②）

全局偏好处冲突链最低优先级。**在从 charter 扩写 spec 之前**完成（无 `FEATURE_DIR` 也要先向用户提问；上游须 `gate-charter` PASS）：

1. 扫描 User Rules / Team Rules / `AGENTS.md` / Memories，列出可能来源。
2. 用户选 **ignore(默认) / selective / adopt**（不替用户决定）。
3. 建特性目录后写入 `FEATURE_DIR/global-prefs.yml`（`decision` + `confirmed: true`）；`stack.yml` 存在时同步 `global_prefs` / `global_prefs_allow`。
4. `gate-global-prefs.sh` PASS 后才可结束 specify（`gate-spec-coverage` 会 delegate）。

trivial 且无额外全局来源时，仍须落盘 `confirmed: true` + `decision: ignore`（可同轮确认，不可跳过文件）。
