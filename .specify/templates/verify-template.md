# Verify 测试报告: [FEATURE NAME]

**Date**: [DATE] | **Form**: [web|desktop|cli|service|library|pipeline] | **Coverage**: verify-coverage.yml

> 由 `sync-verify.sh` 从 spec/tasks 生成清单（US + Edge Cases + 形态专项）。**AI 主导测试，人审本报告**。
> 能自动的 AI 已自动跑；标「需人辅助」的项，AI 请你协助后补「人工确认」再结案。
> 任一项空白/「待跑」/缺人工确认 → `gate-verify.sh` BLOCK。

## 机械门（gate-verify.sh）

| 命令 | 退出码 |
|------|--------|
| … | 0 |

`gate-verify.sh`: **PASS** / **FAIL**

## 验收场景（spec User Story · 须实跑）

> 结果列：✓ 通过 / ✗ 失败 / 需人辅助(原因 + 给人的步骤 + 「人工确认: …」)。

| 场景 | 结果 | 执行 | 证据 |
|------|------|------|------|
| US1 … | ✓ | AI 自动 / AI 截图判断 / 需人辅助 | … |

## 边界与异常（spec Edge Cases · 逐条结案）

> 每条须 `- [x]`（含证据）；无关写 `- [x] N/A: 理由`。

- [ ] (EDGE-1) … — 证据:

## 形态专项 DoD（form · 逐条结案）

> AI 先自动验证；`AI 截图判断` 项拿不准时叫人辅助并记『人工确认: …』。

- [ ] (PF-1) [AI 自动] … — 证据:

## 需人辅助项汇总（如有）

| 项 | 原因 | 给人的步骤 | 人工确认 |
|----|------|-----------|----------|
| … | … | … | … |
