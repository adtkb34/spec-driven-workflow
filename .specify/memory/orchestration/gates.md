# 可执行门（Gates · 先跑脚本，退出码即真相）

关键质量项由 `.specify/scripts/bash/` 脚本机械判定，**非零即停**：

| 时机 | 脚本 | 作用 |
|------|------|------|
| charter 结束 | `gate-charter.sh` | `charter.yml` 已 `confirmed: true`；`charter.md` 非模板 |
| specify 开场 | （对话）+ `global-prefs.yml` | 环境隔离：用户选 ignore/selective/adopt |
| specify 结束 | `gate-global-prefs.sh` | `global-prefs.yml` 已 `confirmed: true`（或 legacy `stack.yml` global_prefs） |
| specify 结束 | `gate-spec-coverage.sh` | Post-Draft Ping 落盘；**delegate** `gate-global-prefs.sh` |
| 进 plan 前 | `gate-clarify.sh` | 占位符扫描 + **delegate** `gate-global-prefs` + `gate-spec-coverage` |
| 进 plan/tasks/implement 前 | `gate-stack.sh` | `stack.yml` 存在、`confirmed: true`、有 `form`；stack 确认时 spec Input Q&A ⑤ 须有 Q→A |
| plan 后 / analyze | `activate-dimensions.sh` | 按 `stack.yml` 输出该激活的条件维度 |
| analyze | `gate-analyze.sh` | 聚合：无模糊点/覆盖度/栈已确认/plan.md 存在/故事有落点/维度路径可解析 |
| tasks 后 / implement 后 | `sync-verify.sh` | 从 spec/tasks 生成 coverage 并合并 verify.yml |
| implement 后 | `gate-verify.sh` | sync + 跑 verify.yml + 对齐 + 扫残留 |
| verify 后（release.enabled） | `gate-deliver.sh` | per-feature：前置 verify + deliver.yml + PR/CI/SHA |
| 用户触发上线 | `gate-release.sh` | 仓库级：includes 都已 deliver + release.yml + 回滚/SHA |

`phase-brief.sh --unlock-status` **实时**跑 gate，**不在 phase.yml 存 unlock 布尔值**。

门只判可机械判定项；主观质量仍由 strong 模型判断，门与人工互补。

## analyze 硬 checklist

- [ ] 每条用户故事在 plan / tasks 中有落点
- [ ] 术语 / 数据模型 / 交互与 spec 一致
- [ ] spec 无残留 `[NEEDS CLARIFICATION]`，覆盖度门 PASS，技术栈已确认
- [ ] plan.md 存在
- [ ] 运行方式可行（选型与部署方式相容）
- [ ] 条件领域维度激活与技术栈一致
- [ ] 已识别移交 implement 的技术风险点

## 质量门（阶段间硬约束）

- 进 `specify` 前：`gate-charter.sh` PASS（P0/unlock，不在 specify 重复登记 gate）
- 进 `plan` 前：clarify gate + 技术栈闸门（stack.confirmed）
- 进 `implement` 前：`gate-analyze.sh` PASS
- `implement` 之后：必须经 `verify`，DoD 全过
- `release.enabled` 时：verify → deliver →（用户触发）release

## 红线

零模糊点 / 技术栈已确认 / 功能不漏 / 运行方式可行 / 验证而非声称 / 一致性优先 / 能力固化 / 可回滚 / 外科式变更。
