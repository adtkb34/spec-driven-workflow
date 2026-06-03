---
name: "speckit-release"
description: "Execute the release paradigm AFTER verify: ship to Git/PR/CI-CD/线上环境 with maturity-tiered DoD, immutable artifact, rollback path and evidence. Also a generator that emits per-project deploy scripts for new projects."
compatibility: "Requires spec-kit project structure with .specify/ directory; runs after gate-verify passes"
metadata:
  author: "authored 2026-06-03"
  source: "synthesized from DORA / Progressive Delivery / GitHub flow + Environments / expand-contract / feature flags"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## 这是什么

本 skill 覆盖**两个频率/触发/粒度都不同的环节**（对应 deploy ≠ release、CD ≠ Continuous Deployment）：

- **deliver（交付）**：跟 MR 节奏，**每个 feature `verify` 通过后可自动跟**——开 PR → 等 CI 绿 → 合并 main → 到 staging。per-feature，证据 `specs/<feature>/deliver.md`，门 `gate-deliver.sh`。
- **release（上线）**：**仅用户显式要求**（"上线/发版"），低频，**可聚合多个已交付 feature** 渐进发布到生产 + 健康检查 + 回滚 + 取证。仓库级 `.releases/<version>/release.md` + `RELEASES.md` 账本，门 `gate-release.sh`。

边界：verify 管"产物对不对" → deliver 管"合进 main、到 staging" → release 管"上没上去生产 + 能否回滚"。三者不可互相替代。

此外本 skill 还是**生成器**：对新项目按 `strategy` 产出专属 `deploy/` 脚本骨架。

完整范式（两环节模型 + 7 原则 + 6 阶段 + T0–T3 + 回滚矩阵）见 `.specify/memory/release-profiles.md`。**先读它**（L2）。

## 硬前置（不可跳过）

- **deliver 前置**：本 feature `verify.md` 存在且 `gate-verify.sh` PASS。
- **release 前置**：纳入本次上线的**每个 feature 都已 deliver**（`gate-deliver.sh` PASS）。
- **release 触发**：**仅用户显式要求才执行**——不在 verify/deliver 后自动上生产。
- `stack.yml` 有 `release:` 段且 `release.enabled: true`（trivial/纯本地工具可 `enabled: false` 跳过）。
- 模型路由：deliver 脚本执行用 fast 档；release 的 go/no-go 裁决用 **strong 档**（裁决不能比被测对象弱）。

## 七条核心原则（执行时不可违背 · 详见 release-profiles.md）

1. 小批量 + 短命分支 + 频繁合并  2. 解耦部署与发布（feature flags）  3. 不可变制品（一次构建多处部署，SHA 标记）
4. 自动回滚优先于自动部署  5. 渐进暴露 + SLI 闸（T2+）  6. expand-contract 数据库迁移  7. 全程取证 / 部署标记（DORA）

## 执行流程

### 第 0 步：判定 tier 与策略
读 `stack.yml.release`（或 `release.yml`）。无则按 `complexity` 给默认建议并**与用户确认**：
- `trivial` → T0（或 `enabled:false`）；`standard` → T1；`complex` → T2+。
- 策略（`strategy`）须与目标环境相容：自托管单机 → `ssh-compose`；k8s/云可路由 → `canary`/`blue-green`；前端托管 → 平台 Git 集成；需 A/B 或暗发布 → `feature-flags`。
- **生产闸 `gate`**：业务系统默认 `B`（prod 前人工确认）；纯内部工具可 `A`。

### 第 1 步（仅新项目 / 缺脚本时）：生成 deploy 脚本骨架
若项目无 `deploy/`（或用户要求重建），按 `strategy` 模板产出，并把占位按本项目实填（仓库结构 / 健康端点 / 远端路径 / 版本策略 / 构建变体）：

- `deploy/preflight.sh`：在发布分支、工作区干净（或 `ALLOW_DIRTY=1`）、配置存在、目标可达。
- `deploy/quality.sh`：**复用 verify 的测试/构建命令**再跑一遍（生产构建语境）。
- `deploy/deploy.sh`：构建**不可变制品（SHA 标记）+ manifest** → 传输 → 激活（按策略：scp+docker load+compose / docker push+gcloud run / git push+vercel / kubectl+argo）。
- `deploy/healthcheck.sh`：发布后探活（HTTP `/health` 200 / 进程存活 / 关键端点），**退出码为准**。
- `deploy/rollback.sh`：**一键切回上一个 release**（红线:可回滚；T0 起必备）。
- T1+ 追加 `deploy/smoke.sh`（staging 冒烟）；T2+ 追加 `deploy/canary.sh`（每步 SLI 比对基线、破阈自动回滚）。
- 同时生成/更新 `FEATURE_DIR/release.yml`（见 `.specify/templates/release-template.yml`）。

> 对**已有发布脚本的项目**（如 `now_order_auto/deploy_v2`）：**不重造**，而是用 release-profiles 当尺子校准——补齐缺的 `rollback.sh`、`release.md` 证据落盘、部署标记，登记其落在哪个 tier。

### 第 2 步（deliver · 跟 MR 自动）：交付到主干 + staging
对**当前 feature**（verify 已过）执行 A–D，写 `specs/<feature>/deliver.md`，跑 `gate-deliver.sh`：
- **A 分支 + PR**（T0+）：短命分支；开 PR（`gh pr create`）；分支保护要求 CI 必过 + 评审。
- **B PR-CI**（T0+）：等远端绿灯（`gh pr checks --watch` / `gh run watch`），**不靠本地自测**。红 → 回 implement 修 → 重跑 verify → 重新 deliver。
- **C 合并 main**（T0+）：`gh pr merge`；构建**不可变制品**（SHA）。
- **D staging + smoke**（T1+）：部署 staging（同制品）→ 冒烟/关键验收 → **DB 迁移 expand 阶段**（向后兼容）。
- 跑 `gate-deliver.sh`：前置 verify + 命令全 0 + deliver.md 有 PR/CI/SHA（T1+ 加 staging）。PASS → 该 feature **可纳入某次上线**。

### 第 3 步（release · 仅用户触发）：聚合上线到生产
**等用户说"上线/发版"**才进入。选定版本号建 `.releases/<version>/`，写 `release.yml`（`includes:` 列出本次聚合的已交付 feature），执行 E–F：
- **E 生产渐进**（T2+）：canary 1–10% → 每步 SLI 比对 → 绿则扩量；`gate: B` 时 prod 前人工确认；破阈**自动回滚**。T0/T1 自托管单机 → docker load + 切换 + 健康检查。
- **F 发布后**（T3）：观察窗 → flag 控可见性 → **DB 迁移 contract 阶段（清旧）** → flag TTL 清理 → 记 DORA 标记。
- 证据写 `.releases/<version>/release.md`（制品 SHA、includes、canary/健康检查、部署 URL、回滚指针、标记），并追加仓库级 `RELEASES.md` 账本。**不留「待发/待验/待上线/TBD」**。
- 跑 `gate-release.sh [.releases/<version>]`：前置 includes 都已 deliver + 命令全 0 + 回滚路径 + SHA + 按 tier canary/SLI（T2+）+ expand-contract（如声明）。
- **失败处理**：上线失败 → 回 release 修后重跑；若暴露功能 bug → 回 implement → 重跑 verify → deliver → 再 release。

### 第 4 步：写运转日志
deliver 与 release 各写一次（release 的 run-log 落在 `.releases/<version>/run-log.md`，门已自动指向）：
```bash
# deliver（per-feature）
.specify/scripts/bash/run-log.sh phase --phase deliver \
  --model "<实际模型 ID>" --skills "delivery" --scripts "gate-deliver.sh" \
  --artifacts "deliver.md,deliver.yml" --note "PR=<链接> CI=<runID> 已合并+staging"
# release（仓库级；先 export SPECIFY_FEATURE_DIRECTORY=.releases/<version>）
SPECIFY_FEATURE_DIRECTORY=.releases/<version> .specify/scripts/bash/run-log.sh phase --phase release \
  --model "<实际模型 ID>" --skills "release,data_migration?,security?" --scripts "gate-release.sh" \
  --artifacts "release.md,release.yml" --note "tier=<T?> includes=<...> 已上线<URL> 回滚=<指针>"
```

## 与其它维度的协作
- **`data_migration`**：涉及 DB 时由它指导 expand-contract，本阶段负责发布编排与回滚证据。
- **`security`**：发布前 `npm audit`/依赖扫描在 PR-CI（B 阶段）跑。
- **`observability`**：T2+ 的 SLI 闸/监控由它支撑；缺则按缺口闸门补通用能力，不强行套云平台。
- **gstack `/ship` 等外部发布工具**：不替代本阶段；如个人习惯使用，须在 gate-release PASS 之后、且不绕过取证。

## 红线（release 专属）
- 不接受"发好了"的口头声称——以健康检查退出码 + release.md 证据为准。
- 任何不可逆改动发布前必须有书面回滚路径。
- 跨前后端/多组件：**后端先（向后兼容）→ 前端后**；迁移 expand-contract，避免线上短暂不兼容。
