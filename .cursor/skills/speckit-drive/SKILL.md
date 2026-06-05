---
name: speckit-drive
description: "Meta orchestrator: greenfield auto-advance between gates, maintain pulse-amend loop, scheduled Automation pulse. Not a P1 pipeline phase."
---

# Speckit Drive

## Triggers

- `/speckit-drive`
- User: 帮我推着做 / 自动迭代 / drive 模式
- `--scheduled` — Cursor Automation maintain pulse only
- `--setup-automation` — configure cron from `.specify/pulse-schedule.yml`

## Entry

1. `phase-brief.sh --mode drive --unlock-status` (or `--mode amend` when executing queue)
2. Read `.specify/memory/orchestration/iteration-drive.md`
3. Seed if missing: `drive.yml`, `pulse-log.md`, `iteration-queue.yml` from `.specify/templates/`

## drive.yml (required)

- `consent: true` before auto-advance or scheduled pulse (except first-time setup explained to user)
- `tier: greenfield | maintain`
- `auto_advance: true` for greenfield loop
- `max_auto_steps` / `max_iterations` caps
- `pause_at`: charter_confirm, global_prefs, stack_confirm, verify_needs_human, release

## Greenfield loop

Phase order: `charter` → `specify` → `clarify` → `plan` → `analyze` → `tasks` → `implement` → `verify` → (`deliver`) → (`release` user-only)

Each iteration:

1. Read `FEATURE_DIR/phase.yml` → `current_phase`
2. `phase-brief.sh --phase <current> --unlock-status`
3. If next human gate in `pause_at` → summarize + **one question**; wait for user; do not invoke next speckit phase until cleared
4. Else invoke the **next** phase skill (full ceremony: 5-line opening → user「继续」when required)
5. `run-log.sh phase` with actual gates run; decrement `max_auto_steps`
6. Stop when `max_auto_steps == 0`, gate fails twice, or user stops

After verify PASS, offer switching `tier: maintain` for pulse loop.

## Maintain loop

1. **Pulse** — one question per invocation; focus rotation: `experience` → `new_demand` → `priority` → `regression` (see `pulse_focus` in repo `.specify/pulse-schedule.yml` or auto-pick from `pulse-log` gaps). Append row to `pulse-log.md`.
2. **Triage** — user confirms → add to `iteration-queue.yml` (`OPEN`)
3. **Execute** — only when user says 执行队列 / run queue: `phase-brief --mode amend`; update spec → partial clarify/plan → implement → **gate-verify**
4. **Close** — mark queue `DONE`; increment `current_iteration`; stop at `max_iterations`

Activate registry `product_pulse` (Read `.cursor/skills/speckit-pulse/SKILL.md`) for question phrasing.

## Scheduled pulse (`--scheduled`)

For Cursor Automation only:

1. `check-pulse-schedule.sh --json` at repo root — exit if `should_run: false`
2. Resolve `FEATURE_DIR` from JSON
3. Ensure `drive.yml` exists; set `tier: maintain`; narrow `consent` for pulse-only if documented in constitution
4. Ask **one** question (focus from `pulse_focus.round_N` or `runs_completed+1`)
5. Wait for user reply in thread; record answer in `pulse-log.md`
6. `record-pulse-run.sh` at repo root
7. **Do not** amend/implement/release in same run

## Setup automation (`--setup-automation`)

1. Ensure `.specify/pulse-schedule.yml` exists (from template)
2. `render-pulse-cron.sh --list` → N cron expressions for N `round_times`
3. Read `.specify/templates/automation-maintain-pulse.prompt.md` as Automation instructions
4. Use automate skill + `open_automation` to create **N** scheduled automations (one per round)
5. Document names: `SpecKit Pulse · <repo> · round k/N`

## Completion

- Report tier, steps remaining, next recommended action
- `--scripts` on run-log must list gates actually run (`gate-drive.sh` when closing a drive session)
