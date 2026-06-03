# 交付与发布范式（Deliver & Release Paradigm）

> 「合并/MR」和「上线」是两种**频率、触发、粒度都不同**的事，故分成两个环节
> （对应业界 Continuous Delivery ≠ Continuous Deployment、deploy ≠ release）：
>
> | 环节 | 触发 | 频率 | 粒度 | 证据位置 | 门 |
> |------|------|------|------|----------|----|
> | **deliver（交付）** | 每个 feature `verify` 通过后**可自动跟**（跟 MR 节奏） | 高 | per-feature | `specs/<feature>/deliver.md` | `gate-deliver.sh` |
> | **release（上线）** | **仅用户显式要求**（"上线 / 发版"） | 低 | **可聚合多个已交付 feature** | 仓库级 `.releases/<version>/release.md` + `RELEASES.md` 账本 | `gate-release.sh` |
>
> - **deliver**：开 PR → 等 CI 绿 → 合并 main → 部署 **staging** + smoke。属 per-feature 流水线的延伸，verify 之后可自动走。
> - **release**：把若干**已 deliver** 的 feature 聚成一个版本，**渐进发布到生产** + 健康检查 + 回滚 + 取证。**不绑单个 feature 目录**，证据进仓库级发布账本。
> - **共同边界**：verify 管「产物对不对」；deliver 管「合进主干、到 staging」；release 管「上没上去生产 + 能否回滚」。三者不可互相替代。
>
> 本范式综合：DORA（State of DevOps）、Progressive Delivery（James Governor / RedMonk）、trunk-based development、
> GitHub flow + GitHub Environments、expand-contract（parallel change）迁移、feature flags、自动回滚（Argo Rollouts / Flagger 的 SLI 闸）。

## 七条核心原则（不变量 · deliver 与 release 通用）

1. **小批量 + 短命分支 + 频繁合并**（trunk-based / GitHub flow）：分支宜 < 2 天，降低集成风险、缩短前置时间。
2. **解耦「部署」与「发布」**（feature flags）：代码可先"暗部署"到 prod，flag 控可见性；功能回滚 = flag 置 OFF（秒级）。**这正是 deliver 与 release 可分离的技术基础。**
3. **不可变制品（一次构建，多处部署）**：用 `commit SHA` 标记；staging 与 prod 跑**同一制品**，杜绝环境漂移。
4. **自动回滚优先于自动部署**：回滚若手动则慢，慢则不敢发。回滚路径必须存在、快、可一键/自动触发。
5. **渐进暴露 + SLI 闸**（release · T2+）：canary 每步用错误率/延迟比对基线，**通过才扩量、破阈即回滚**；禁止"定时器式 canary"。
6. **expand-contract 数据库迁移**：先加（向后兼容）→ 发代码 → 后删旧；每阶段独立可回滚，旧版本仍能读写。
7. **全程取证 / 部署标记**：每次 deliver/release 记 `timestamp + git_sha + outcome(success|fail|rollback)`——对齐红线「验证而非声称」，可读出 DORA 五指标。

## DORA 北极星（度量目标，不是阶段）

部署频率 / 变更前置时间 / 变更失败率 / 失败恢复时间 / 返工率。
范式不强制达 elite 档，但要求每次 deliver/release **留下可算这些指标的标记**（原则 7）。

## 6 阶段流水线（归属 deliver 还是 release · 平台无关骨架）

```
[deliver · 跟 MR 自动] A 分支+PR → B PR-CI(快) → C 合并 main → D staging+smoke
                                                                      │
                              （攒若干已交付 feature，用户说"上线"才进入）
                                                                      ▼
[release · 用户触发]                                E 生产渐进 → F 发布后
```

| 阶段 | 环节 | 做什么 | 关键门 / 实践 | 起始 tier |
|------|------|--------|--------------|-----------|
| **A 分支 + PR** | deliver | 短命分支；PR 作评审与状态检查边界 | 分支保护：CI 必过 + 评审才能合并 | T0 |
| **B PR-CI**（目标 <10–15 min） | deliver | lint → unit(并行) → **build 不可变制品(SHA)** → integration → secret/依赖扫描 | monorepo 路径过滤；测试分片并行 | T0 |
| **C 合并 main** | deliver | 全量测试 → 构建**生产制品**（仅此一次构建） | trunk 永远可发布 | T0 |
| **D staging + smoke** | deliver | 部署 staging → 冒烟/关键验收 → **DB 迁移 expand 阶段** | staging 与 prod 同制品；健康检查取证 | T1 |
| **E 生产渐进发布** | release | canary 1–10% → 每步 SLI 比对基线 → 绿则扩量(25/50/100%) | GitHub Environments 保护规则（prod required reviewers）；破阈**自动回滚** | T2 |
| **F 发布后** | release | 观察窗 → flag 控可见性 → **DB 迁移 contract 阶段(清旧)** → flag TTL 清理 → 记 DORA 标记 | flag > 45 天视为债；flag 清理是 DoD 一部分 | T3 |

> T0 项目可能没有 staging/canary：deliver 退化为「PR+CI+合并」，release 退化为「在生产单机上 docker load + 切换 + 健康检查 + 一键回滚」（`now_order_auto/deploy_v2` 即此形态）。**越高 tier 把 D/E/F 逐步自动化**，不强求一步到位。

## 回滚矩阵（按变更类型 · 红线「可回滚」的落地）

| 变更类型 | 回滚方式 | 速度 |
|----------|----------|------|
| **二进制 / 镜像** | 任一 SLI 破阈 / 健康检查失败 → 流量切回上一版本（或 `rollback.sh` 切上一个 release） | 秒~分钟 |
| **数据库 schema** | expand-contract 保证每阶段旧版本仍可读写；回滚 = 停在上一阶段 | 阶段隔离 |
| **功能** | feature flag 置 OFF（**最快，无需重部署**） | 秒 |

**硬约束**：任何不可逆改动（破坏性迁移、删数据、不兼容 API）**上线前**必须有书面回滚路径，写进 `release.md`。

## 部署策略选型（按场景，不是都要 canary）

| 策略 | 何时用 | 代价 |
|------|--------|------|
| rolling | 默认（k8s）、低风险 | 最低 |
| blue-green | 回滚速度是硬需求 | 2x 基础设施（切换窗口） |
| canary | 要真流量验证、风险有界 | 流量路由 + 监控复杂度 |
| feature flags | 解耦 deploy/release、A/B | flag 生命周期管理 |
| **ssh + compose（自托管单机）** | VPS、无 k8s/云、成本敏感 | 无内建流量切分，靠 release 归档 + `rollback.sh` |

---

## 成熟度档位 DoD（按 `tier` 选档 · 逐条留证据）

### 通用底线（deliver 与 release 都要过）
- **制品可追溯**：发布物带 `git_sha` + `version`，记入 manifest/证据文件。
- **健康检查取证**：实际探活（HTTP `/health` 200 / 进程存活 / 关键端点 200），**退出码为准**，不接受口头声称。
- **部署标记**：记 `timestamp + git_sha + outcome`。
- 证据（命令、退出码、URL、截图/响应）落到对应证据文件。

### deliver DoD（per-feature · `gate-deliver.sh`）
- **硬前置**：本 feature `verify.md` 存在且 `gate-verify.sh` PASS。
- A 分支+PR：开 PR（或记录 MR），分支保护要求 CI 必过 + 评审（T1+）。
- B PR-CI：远端 CI 绿灯（`gh pr checks --watch` / `gh run watch`），**不靠本地自测**。
- C 合并 main：构建不可变制品（SHA）。
- D（T1+）：部署 staging + smoke/关键验收过；涉及 DB 走 expand 阶段。
- 证据写 `specs/<feature>/deliver.md`（PR 链接 / CI runID / 制品 SHA / staging 结果）。

### release DoD（仓库级聚合 · `gate-release.sh`）
- **硬前置**：纳入本次发布的**每个 feature 都已 deliver**（`deliver.md` 存在且其 gate PASS）。
- **回滚路径存在**：`rollback` 命令或上一个 release 指针。
- E（T2+）：canary + SLI 闸；破阈自动回滚；`gate: B` 时 prod 前人工确认。
- F（T3）：feature flag / contract 清旧 / flag TTL / DORA 标记。
- 证据写仓库级 `.releases/<version>/release.md` + 追加 `RELEASES.md` 账本（version、纳入的 feature/commit、部署 URL、回滚指针、标记）。

### 按 tier 递进
- **T0 最小合规**：deliver=PR+CI+合并；release=生产激活 + 健康检查 + **一键 `rollback.sh`** + 标记。（自托管/早期项目；`deploy_v2` 形态）
- **T1 标准**：+ 分支保护、自动 staging+smoke、生产人工闸（`gate:B`）、expand-contract。
- **T2 进阶**：+ canary + SLI 自动闸 + 自动回滚。
- **T3 精英**：+ feature flags 解耦、全自动渐进、GitOps、DORA 自动采集。

### unknown（未声明 tier）
- 至少满足「通用底线」；强烈建议回 plan 在 `stack.yml.release` 补 `tier`。

---

## `deliver.yml` 最小示例（放 FEATURE_DIR · 见 deliver-template.yml）

```yaml
tier: T0
artifact: { version_from: git, sha_required: true }
commands:
  - name: open-pr        # gh pr create（或记录 MR）
    run: "bash deploy/open-pr.sh"
  - name: ci-green       # 等远端 CI 绿灯
    run: "bash deploy/ci-wait.sh"
  - name: merge          # gh pr merge
    run: "bash deploy/merge.sh"
  # T1+: staging + smoke
  # - name: staging
  #   run: "bash deploy/deploy.sh --env staging && bash deploy/smoke.sh"
```

## `release.yml` 最小示例（放 `.releases/<version>/` · 见 release-template.yml）

```yaml
version: 20260603-120000-a1b2c3d
tier: T0
strategy: ssh-compose
includes:                 # 本次上线聚合的已交付 feature（每个须 deliver 过）
  - 001-kanban-board
  - 002-markdown-notes-desktop
artifact: { sha_required: true }
commands:
  - name: preflight
    run: "bash deploy/preflight.sh"
  - name: deploy-prod     # 激活生产（按策略：compose / gcloud run / canary）
    run: "bash deploy/deploy.sh --env prod"
  - name: healthcheck
    run: "bash deploy/healthcheck.sh"
rollback:
  command: "bash deploy/rollback.sh"
  pointer: ".releases/PREVIOUS"
gate: B                   # A 全自动直发 | B 生产前人工确认
marker: { record: true }
```

> `gate-deliver.sh` 强制：verify 已过 + commands 全 0 + deliver.md 有 PR/CI/SHA（T1+ 加 staging）。
> `gate-release.sh` 强制：includes 的 feature 都 deliver 过 + commands 全 0 + 回滚路径存在 + release.md 含 SHA 且无占位 + 按 tier 校验 canary/SLI（T2+）/expand-contract（如声明）。
