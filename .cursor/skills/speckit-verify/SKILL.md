---
name: "speckit-verify"
description: "Execute the verify phase: AI-led, evidence-based acceptance of the implemented product before it can be called done. Use after /speckit-implement and before deliver/release. The orchestration layer runs this itself — sub-agent self-reports are NOT acceptance evidence."
compatibility: "Requires spec-kit project structure with .specify/ directory + FEATURE_DIR/stack.yml"
metadata:
  author: "authored 2026-06-03"
  source: "extracted from speckit-implement step 10 + constitution II-bis + verify-profiles.md"
---

# verify 阶段（本工作流自有 · implement 之后必经 · 不接受自我汇报）

「完成」= **被验证过真的能跑**，不是任何 agent（含子 agent）口头声称（constitution II-bis）。
本阶段由**编排层亲自执行**：真启动产物、抓报错、逐条跑验收、留证据。
DoD **按产物形态选档**，档位清单见 `.specify/memory/verify-profiles.md`；对齐协议见
`.specify/memory/verify-sync.md`。

> 本 skill 是 verify 阶段的**统一入口**（与其它 `speckit-*` 阶段对称）。
> `speckit-implement` 收尾会委派到这里；也可单独触发（如维护再入后的重跑 verify）。

## 模型路由

verify **用 strong 档（Opus 系）**——验证是裁判，不能比被测对象更弱（constitution「模型路由」）。

## 流程（顺序不可颠倒）

1. **同步覆盖**：`.specify/scripts/bash/sync-verify.sh` 从 `spec.md` + `tasks.md` 生成
   `verify-coverage.yml`（每条 US + Edge Cases EDGE-n + 形态专项 PF-n）并合并 `verify.yml`、scaffold `verify.md`。

2. **AI 主导逐条实测**（测试主导权见 verify-profiles.md「测试主导权」），按 owner：
   - `ai-auto`：直接脚本化跑（命令 / HTTP / CLI / headless / WebDriver），证据=退出码/断言；
   - `ai-visual`：启动产物 + **自动截图**判断三态/白屏/UX，截图存 `verify-artifacts/`，`verify.md` 引用路径；
   - `needs-human`（例外，能少则少）：在 `verify.md` 标**原因 + 给人的最小步骤**，**显式叫人辅助**并暂停；
     人确认后回填 `人工确认: …` 再结案。**禁止静默跳过、禁止假装通过**。

3. **写证据**：每条 US/EDGE/PF 结果写入 `verify.md`（✓ 或 `- [x]`）。**禁止**「待跑/待 GUI」或空白占位。

4. **跑门**：`.specify/scripts/bash/gate-verify.sh`（内建 sync + 覆盖对齐 + 结案检查 + 残留扫描 + 按 form 选档）。
   非零 → 回 implement 修复 → **重跑 verify**（不得跳过或降低标准）。
   发布前可选：`VERIFY_FULL=1 gate-verify.sh` 跑 `optional: true` 的慢命令（如 `tauri build`）。

## 可执行 DoD（逐条留证据，缺一不可）

1. **真启动**：用 plan 承诺的方式实际跑起来（双击 / 本地 server / 部署）。
2. **零报错**：console / 运行时无 error（抓「空白页」类问题）。
3. **验收全过**：spec 每条 Acceptance Scenario 实跑一遍并记录。
4. **三态可见**：空 / 加载 / 错误态分别截图或描述确认存在。
5. **UX 红线**：交互形态符合 plan（该弹窗不内联）、关键流程（如登录）在位。
   **WebView/Tauri/Electron**：禁 `window.prompt/alert/confirm`（gate-verify 会扫），主流程用应用内 Dialog。
6. **无残留**：声明的 `scan_paths` 内无 TODO / stub / 空函数 / 占位实现。
7. **测试真跑**：声称的测试实际运行并通过（退出码 0），而非「应当通过」。

## Done When

- [ ] `gate-verify.sh` exit 0（声明命令全绿、覆盖对齐、无残留、GUI closure 无「待跑」）
- [ ] `verify.md` 七条 DoD 逐条留证据；`needs-human` 项均已回填人工确认
- [ ] 任一未过 → 已回 implement 修复并重跑 verify
- [ ] （维护再入场景）修 bug 已在 spec/verify 补一条防复发验收项

## 红线

- 子 agent 自我汇报**不算**验收证据。
- 未过 DoD 的产物一律视为未完成；trivial 也不豁免（走轻量档但仍必过 verify）。
