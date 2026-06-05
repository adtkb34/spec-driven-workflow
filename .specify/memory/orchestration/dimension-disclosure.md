# 渐进披露协议（D1/D2/D3 · 控指令稀释）

命名：**P0–P2** = 阶段树（phase-discipline / speckit skill / gates）；**D1–D3** = registry 维度披露层（原 L1/L2/L3）。

1. **D1 = `summary`**（registry 内一行 what+when）：P2 通过后、由 `activate-dimensions.sh` 命中的维度**先只注入 summary**。
2. **D2 = `path` 全文 SKILL.md**：仅当本步确需该维度细则时才 `Read` 全文。
3. **D3 = skill 内 `references/`**：L2 仍不够时再下钻。

判定从简：**能用 D1 完成就停在 D1**；拿不准先 D1，遇到具体决策再升 D2。
`meta: true` 的维度（如 `session_handoff`）不自动注入，仅用户显式触发时才读。

## 每个阶段开始时（必做 · 修订顺序）

1. **P0**：`phase-brief.sh --questions-only`（或完整 brief）— 只带提问，不带规则正文。
2. **P2**：跑本阶段所需 gate（`--unlock-status` 实时查，**不**读 phase.yml 里的 unlock 布尔缓存）。
3. **P2 通过后** → `activate-dimensions.sh --phase <phase>` → 注入各命中维度的 **D1 summary**。
4. **full ceremony**：5 行开场 + 等用户「继续」→ 再 `Read` speckit 阶段 SKILL.md（P1）。
5. **命中即用**：维度在注册表中有 skill → 直接使用，不询问。

**charter · brainstorming 子模式** → abc 不足用 `partial_background`；standard/complex 用 `partial_approaches` 写入 charter `## Approach Trade-offs`。Speckit 内禁止 brainstorming 终态 `writing-plans`（见 brainstorming SKILL §Speckit overlay）。

**specify** → 环境隔离闸门 + 从 charter 扩写；brainstorming 仅 scope 冲突时。

**plan · grill_with_docs** → plan 初稿后对抗审查 spec/plan/CONTEXT/ADR；`gate-grill.sh` 仅登记 plan 一次。trivial 可 `grill.yml` waived。

## 未命中 → 用户闸门

某个本应在本阶段发挥作用的维度在注册表中没有对应 skill 时，**立即暂停**并问用户是否引入专门 skill。
- 答「需要」→ 走【补全路径】。
- 答「不需要」→ 走【三层降级】。
- 禁止由 AI 自行决定是否降级或联网。

## 补全路径 / 三层降级

见主规则 `workflow-orchestration.mdc` 索引；细节不变：隔离区 → 登记 registry → 泛化兜底 → 临时 checklist → 最后才联网。
