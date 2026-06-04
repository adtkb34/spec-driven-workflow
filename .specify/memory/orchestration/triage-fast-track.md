# 复杂度分级与快速通道（Triage & Fast-Track）

`specify` 起始给出复杂度并写入 `FEATURE_DIR/stack.yml` 的 `complexity`：

- **trivial**（须全满足）：单一关注点、无登录、无超本地持久化、可回滚、不接外部 API、不引入新架构。
- 任一不满足 → `standard`；涉及架构/迁移/多模块/不可逆 → `complex`。

**trivial 快速通道**：ceremony=minimal（见 phase-index）；跳过 clarify 提问（仍跑 `gate-clarify.sh`）、analyze 轻量核对、技术栈沿用既有栈可免暂停（但 `stack.yml` 仍 `confirmed: true`）、**仍必过 verify 轻量档**。
**standard/complex 走全流水线**。拿不准默认按更高档。

brainstorming 与 speckit-specify 对齐（见 phase-index `brainstorming_modes`）：
- trivial + 背景充分 → `none`（勿误报 brainstorming 为已用 skill）
- 背景不足 → `partial_background`（一次一问）
- standard/complex → `partial_approaches` 或 `full`
