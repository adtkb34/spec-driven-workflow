# 可执行门（Gates · 先跑脚本，退出码即真相）

关键质量项由 `.specify/scripts/bash/` 脚本机械判定，**非零即停**：

| 时机 | 脚本 | 作用 |
|------|------|------|
| 进 plan 前 | `gate-clarify.sh` | spec 无 `[NEEDS CLARIFICATION]`/TODO |
| 进 plan/tasks/implement 前 | `gate-stack.sh` | `stack.yml` 存在、`confirmed: true`、有 `form` |
| plan 后 / analyze | `activate-dimensions.sh` | 按 `stack.yml` 输出该激活的条件维度 |
| analyze | `gate-analyze.sh` | 聚合：无模糊点/栈已确认/故事有落点/维度路径可解析 |
| tasks 后 / implement 后 | `sync-verify.sh` | 从 spec/tasks 生成 coverage 并合并 verify.yml |
| implement 后 | `gate-verify.sh` | sync + 跑 verify.yml + 对齐 + 扫残留 |
| verify 后（release.enabled） | `gate-deliver.sh` | per-feature：前置 verify + deliver.yml + PR/CI/SHA |
| 用户触发上线 | `gate-release.sh` | 仓库级：includes 都已 deliver + release.yml + 回滚/SHA |

`phase-brief.sh --unlock-status` **实时**跑 gate，**不在 phase.yml 存 unlock 布尔值**。

门只判可机械判定项；主观质量仍由 strong 模型判断，门与人工互补。

## analyze 硬 checklist

- [ ] 每条用户故事在 plan / tasks 中有落点
- [ ] 术语 / 数据模型 / 交互与 spec 一致
- [ ] spec 无残留 `[NEEDS CLARIFICATION]`，技术栈已确认
- [ ] 运行方式可行（选型与部署方式相容）
- [ ] 条件领域维度激活与技术栈一致
- [ ] 已识别移交 implement 的技术风险点

## 质量门（阶段间硬约束）

- 进 `plan` 前：clarify gate + 技术栈闸门（stack.confirmed）
- 进 `implement` 前：`gate-analyze.sh` PASS
- `implement` 之后：必须经 `verify`，DoD 全过
- `release.enabled` 时：verify → deliver →（用户触发）release

## 红线

零模糊点 / 技术栈已确认 / 功能不漏 / 运行方式可行 / 验证而非声称 / 一致性优先 / 能力固化 / 可回滚 / 外科式变更。
