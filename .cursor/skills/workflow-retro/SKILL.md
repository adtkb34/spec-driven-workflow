---
name: "workflow-retro"
description: "把事故/verify 失败/dogfood 发现系统化地折回工作流补丁(门/profile/红线/registry/规则),而非一次性手工修。Use when a verify failure or a shipped-then-broken feature exposes a workflow gap, after a dogfood run, or when a class of issue recurs. Triggers: 复盘/retro/工作流疏漏/防复发/postmortem。"
metadata:
  author: "authored 2026-06-03"
  source: "synthesized from blameless postmortem + 002 workflow-gaps.md 实战"
  meta: true
---

# 工作流自反馈闭环（Workflow Retro）

工作流的价值不在于第一次跑对，而在于**每次跑错都被折成一条机制**，让同类问题不再发生。
这条 skill 把「事后手工补一下」变成**确定性的复盘→补丁→回归**流程。典范见
`specs/002-markdown-notes-desktop/workflow-gaps.md`（笔记 App 事故 → 5 处工作流补丁）。

**何时触发**：① verify 失败或线上 feature 暴露 bug；② 一次 dogfood 跑完；③ 同类问题第二次出现；
④ 用户显式 `/retro`。**不自动绑阶段**（meta），由编排层或用户触发。

## 流程（六步，逐步留痕）

1. **记事故**：一句话说清「什么滑过去了 + 在哪个阶段滑的」（specify / plan / tasks / implement /
   verify / gate / registry / 规则）。**落点按范围分**：
   - **feature 级**（某特性内的疏漏）→ `specs/<feature>/workflow-gaps.md`（按阶段分节）；
   - **流程/跨 feature 级**（工作流本身的决策/机制问题）→ 仓库级 `.specify/memory/retro-log.md`（一事一条）。

2. **根因到层**：把症状追到**工作流的某一层**，而非只修产品代码。问：
   *哪一道门本该拦住它？为什么没拦？*（如 002：`form: cli` 选错 + 把 gate-verify PASS 当 verify 完成）。

3. **选补丁目标（优先级：机制 > 文字）**——对齐宪法「声称→机制可强制」：
   | 目标 | 何时选 | 产物 |
   |------|--------|------|
   | 门脚本 `gate-*.sh` | 可机械判定的漏判 | 改脚本 + **必加回归** |
   | `verify-profiles.md` 档 | 某产物形态的 DoD 缺一条 | 新增/补该档清单 |
   | constitution 红线 | 缺一条不可豁免的原则 | 加红线 + **升版本/changelog** |
   | `registry.yaml` 维度 | 某质量维度没人负责 | 走缺口闸门补 skill / 改 activate_if |
   | `workflow-orchestration.mdc` | 阶段顺序/激活规则缺口 | 改规则 |

4. **机制优先**：能加进门脚本机械拦的，**绝不只写进文档靠自觉**。文字约束是最后兜底。

5. **加回归**：任何 `gate-*.sh` 改动，必须在 `.specify/tests/run-gate-tests.sh` 加一条
   **PASS/BLOCK 双路径**用例并跑绿（否则门本身无人守）。

6. **结账**：在 `workflow-gaps.md` 的补丁表把每条标 ✅ 已落地；红线变更则更新 constitution
   版本号 + changelog 注释，并同步 `ARCHITECTURE.html`（保持一致性红线）。

## 红线

- **不甩锅、对事不对人**（blameless）：复盘只问「流程哪里能更稳」，不追究个人。
- **一次事故至少一条机制**：只改产品代码、不补工作流 = 没复盘（同类必复发）。
- **机制必须可回归**：改了门没加测试 = 没改完。
- **不臆造指标/证据**：缺数据如实标，呼应「验证而非声称」。
