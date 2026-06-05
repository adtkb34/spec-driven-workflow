---
name: speckit-pulse
description: "Maintain-tier pulse: one structured question about experience, new demand, priority, or regression. Used by speckit-drive and scheduled Automation."
---

# Speckit Pulse

Delegate to [speckit-drive/SKILL.md](../speckit-drive/SKILL.md) for full loop. This skill only defines **question quality**.

## One question only

- Read `charter.md`, `spec.md` (summary), recent `pulse-log.md`, `verify.md` highlights
- Pick focus: `experience` | `new_demand` | `priority` | `regression`
- Prefer `pulse_focus.round_k` from `.specify/pulse-schedule.yml` when scheduled
- Do not repeat the same focus as the last closed pulse row

## Examples

- **experience**: 过去一周用下来，最不顺手的一步是什么？（0–10 分可选）
- **new_demand**: 有没有「本来没有、现在特别想要」的能力？是否算本期？
- **priority**: 若只改一处，先修 bug、先 polish，还是先加功能？
- **regression**: 上次 verify 之后，有没有又坏掉或没测到的场景？

## Output

Append to `pulse-log.md` table; show question in chat with ★ preferred option when applicable.
