# AI 驱动推进（Drive · meta 模式）

**不是 P1 阶段**。通过 `workflow-index.yml` → `modes.drive` 与 `/speckit-drive` 触发。

## Tiers

| Tier | 何时 | 行为 |
|------|------|------|
| **greenfield** | 新特性，`drive.yml` → `tier: greenfield` + `consent` + `auto_advance` | 读 `phase.yml` + `phase-brief --unlock-status`，在 **pause_at** 闸门暂停，否则 invoke 下一 `speckit-*` |
| **maintain** | verify/deliver 后 | pulse → `iteration-queue.yml` → amend → verify；可多轮至 `max_iterations` |

## 与 clarify / pulse / grill 分工

- **clarify**：spec 协作补洞（一次一题，④ 为主）
- **drive pulse**：交付后回访（体验 / 新需求 / 优先级 / 回归），落 `pulse-log.md`
- **grill-with-docs**：plan 后文档对抗（`grill-log.md`）
- **drive** 不替代 charter abc、不重复 clarify 问卷

## Scheduled pulse（Cursor Automation）

仓库级 [`.specify/pulse-schedule.yml`](../../templates/pulse-schedule-template.yml)：

- `project_window` / `daily_window`：何时允许打扰
- `cadence.rounds_per_period` + `round_times`：周期内几轮、各轮时刻
- 状态：`.specify/pulse-schedule-state.yml`（`runs_completed` / `period_id`）

脚本：

- `check-pulse-schedule.sh --json` — Automation 入口先跑
- `record-pulse-run.sh` — pulse 成功后递增配额
- `render-pulse-cron.sh --list` — setup 生成 N 条 cron

Setup：`/speckit-drive --setup-automation` → 读 yml → `render-pulse-cron` → 按 [automate skill](../../../.cursor/skills-cursor/automate/SKILL.md) 打开 Automations 编辑器（每轮一条 Automation）。

**一期边界**：定时任务 **只采集 pulse**（一次一问）；queue → amend 须用户显式 `/speckit-drive` 或授权 `auto_advance`。

## 红线

- 不得绕过阶段门；`release` 仅用户触发
- verify 证据须 `verify.md` + gate，不接受 drive 自述
- `drive.yml` 须 `consent: true`（scheduled 可窄化 consent 范围见 constitution）
