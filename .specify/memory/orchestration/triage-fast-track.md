# 复杂度分级与快速通道（Triage & Fast-Track）

**charter** 阶段首次判定并写入 `charter.yml` 的 `complexity`（可同步 `stack.yml`；`gate-charter.sh` 校验）：

- **trivial**（须全满足）：单一关注点、无登录、无超本地持久化、可回滚、不接外部 API、不引入新架构。
- 任一不满足 → `standard`；涉及架构/迁移/多模块/不可逆 → `complex`。

**trivial 快速通道**：ceremony=minimal（见 phase-index）；跳过 clarify 提问（仍跑 `gate-clarify.sh`）、analyze 轻量核对、技术栈沿用既有栈可免暂停（但 `stack.yml` 仍 `confirmed: true`）、**仍必过 verify 轻量档**。
**standard/complex 走全流水线**。拿不准默认按更高档。

brainstorming 与 Speckit 对齐（见 phase-index `brainstorming_modes`）：
- **charter**：abc 不足 → `partial_background`；standard/complex 且 abc 够 → `partial_approaches`（写入 charter `## Approach Trade-offs`）
- trivial + 背景充分 → `none`（勿误报 brainstorming 为已用 skill）
- **specify**：仅 scope 与 charter 冲突或膨胀时激活 brainstorming；**不再**做 abc（已迁 charter）
- `full` 仅用于**脱离 Speckit 特性流水线**的独立项目（终态 `writing-plans`）；特性流水线默认禁止

**trivial · Post-Draft Coverage Ping**：② 无 legacy 迹象 → 一行 waived Q→A，不追问 As-Is；④⑤ 不在 specify 问。仍须 `Input Q&A` 非空（waived 行即可）。
