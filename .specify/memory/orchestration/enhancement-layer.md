# 增强层（Enhancement Layer · 非替换）

注册表里来自 Addy Osmani / Superpowers / Matt Pocock 的维度是**增强**，只 enrich 某阶段子步骤，**不替代** Spec Kit 编排。

1. **冲突裁决优先级**（高 → 低）：
   **Spec Kit 阶段门 > constitution > registry 维度 skill > 外部 skill 默认行为 > 全局偏好**。
2. **硬约束**：外部 skill **不得**覆盖或降低 `verify` 可执行 DoD、技术栈闸门、模型路由。
3. **条件维度激活**：领域维度带 `when:`，**默认休眠**，只在命中条件后激活（`activate-dimensions.sh` 机械判定）。
4. **`source_grounding` vs `grill-with-docs` 分工**：前者 implement 期查框架/库 API；后者 plan/analyze 期拷问 spec/plan/ADR。
5. **`session_handoff`**（meta，仅 `/handoff` 或显式 @ 触发）：OS 临时目录、只指针不复制、不得替代 verify 证据。

## 环境隔离闸门（specify 起始必做）

全局偏好处冲突链最低优先级。specify 起始扫描 User Rules / AGENTS.md / Memories，问用户 **ignore(默认) / selective / adopt**，写入 `stack.yml` 的 `global_prefs`。trivial 且无检测到来源时可默认 ignore 免打扰。
