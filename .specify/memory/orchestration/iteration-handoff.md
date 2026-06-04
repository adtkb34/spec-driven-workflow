# 迭代与维护再入（amend / handoff）

已过 verify / 已交付 / 已上线的特性被报 bug 或提变更时，**amend 既有特性**，**不从零 specify**。

- **bug fix**：`debugging` 定位 → 外科式修 → **必过 verify**（含防复发回归项）
- **change request（小改）**：先改 spec → 局部重过 clarify/plan/analyze 子步骤 → implement → verify
- **大改/架构级**：当作 `complex` 新特性走全流水线

**再入**：`phase-brief.sh --mode amend`；required gate = `gate-verify.sh`（见 workflow-index modes.amend）。

**handoff**：新会话 `phase-brief.sh --mode handoff --unlock-status`；读 `phase.yml`，勿从零 specify。

**再入红线**：任何再入都必须重过 verify；行为变更先改 spec 再改码；修 bug 必补回归项；再发布走 deliver→release。
