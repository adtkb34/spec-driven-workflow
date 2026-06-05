# Spec-Driven 产品工作流 Constitution

> 本宪法是整条工作流的最高约束，优先级高于任何阶段 skill 的默认行为。
> 完整设计见仓库根目录 `ARCHITECTURE.html`。

## Core Principles

### I. 质量前置（Quality-First）
在写任何代码之前，必须把需求与方案打磨到「零模糊点」。
`spec.md` 中残留任何 `[NEEDS CLARIFICATION]` 时，禁止进入 `plan`。
功能完整性优先：spec 中每条用户故事，必须在 plan 与 tasks 中都有对应落点。

### II. 可控与能力固化（Controllable & Capability-Pinned）
**构建过程不依赖运行时不可控的外部输入，且所用能力可复现**：任何联网获得的能力
（skill、参考资料）必须经审查并固化进注册表后，方可正式使用——固化即锁定来源与版本。
**注意：LLM 输出本身是非确定的，本工作流不承诺"同一提示逐字可复现"**；
可复现指的是**流程、门、激活的能力集合**可复现，而非模型生成的具体字句。

### II-bis. 验证而非声称（Verify, Don't Claim · NON-NEGOTIABLE）
「完成」的定义是**被验证过真的能跑**，而非任何 agent（含子agent）口头声称完成。
implement 之后必须经过 `verify` 阶段：编排层**亲自把产物运行起来**、检查无报错、
逐条执行 spec 的验收场景并留下证据。无证据 = 未完成。
禁止把子agent的自我汇报当作验收依据。

### III. 用户掌方向，AI 掌执行（User Decides Direction）
「要不要做某事 / 要不要引入专门能力」属于产品判断，归用户。
「在约束内如何把它做好」归 AI。
AI 不得用「加开关让用户选」来回避本该自己定的实现细节，
也不得替用户决定「是否需要专门 skill」这类方向性问题。

### IV. 第一性原理与少即是多（First-Principles & Less-is-More）
对每个需求先跑第一性原理拆解（见 first-principles skill）：
能删则删、能简则简，最后才谈自动化。命中否决清单的需求必须明确「不做 / 先不做」。

### V. 一致性与可逆（Consistency & Reversibility）
新模块与既有术语、交互、数据模型保持一致。
不可逆改动（数据迁移、破坏性 API 变更）必须先有回滚方案。

### VI. 增强而非替换（Enhancement over Replacement）
外部来源（Addy Osmani / Superpowers / Matt Pocock 等）的 skill 只**增强**某阶段子步骤，
**不替代** Spec Kit 编排与本工作流自有阶段。冲突裁决优先级（高→低）：
**Spec Kit 阶段门 > constitution > registry 维度 skill > 外部 skill 默认行为 > 全局偏好**。
外部 skill 不得覆盖或降低 `verify` 可执行 DoD、技术栈闸门、模型路由；
子 agent 的自我汇报仍不算验收证据。
专业领域维度为**条件维度**（带 `when:`），默认休眠，命中条件才激活，避免误挂。

### VII. 环境隔离（Context Isolation · 默认不被全局偏好污染）
**全局偏好**（Cursor User Rules / Team Rules、`AGENTS.md`、Cursor Memories、Copilot 用户级 memories）
常驻且跨项目，处于冲突裁决链**最低优先级**。默认立场为**隔离**：未经用户在「环境隔离闸门」
明确放行前，一律不采纳；即便放行，也不得覆盖上位规则（阶段门 / constitution / 维度 skill）。
闸门在 **specify 开场（硬序②，须 charter 已 `gate-charter` PASS）**触发一次：决策记入
`FEATURE_DIR/global-prefs.yml`（`confirmed: true`），并同步 `stack.yml` 的 `global_prefs`；本特性沿用。
背景 abc 与方案取舍在 **charter** 阶段经 brainstorming 子模式完成，不在 specify 重复。
`gate-global-prefs.sh` 机械校验，非仅文档自觉。

## 模型路由（Model Routing）

按任务难度而非死板按阶段切换：

- 前期（理解 + 设计）→ **Opus**：constitution / specify / clarify / plan / analyze / tasks。
  理由：此处决策错误会向下游全面传播，值得用强推理模型。
- 后期（执行）→ **Composer**：implement 默认用快模型。
- **卡住升级**：implement 阶段遇到难调试、架构需返工、或同一任务连续失败时，
  临时升回 Opus，解决后降回 Composer。
- **验证用 Opus**：verify 阶段的判定、根因分析、验收裁决由 Opus 执行
  （验证是裁判，不能比被测对象更弱）。

| 任务类型 | 默认模型 | 升级条件 |
|----------|----------|----------|
| 需求理解 / 澄清 | Opus | — |
| 架构 / 数据模型 / 接口设计 | Opus | — |
| 一致性分析、风险评审 | Opus | — |
| 任务拆解 | Opus | — |
| 常规代码实现 | Composer | 连续失败 / 跨模块重构 → Opus |
| 测试编写 | Composer | 复杂测试设计 → Opus |
| 疑难调试 | Opus | — |
| 验证 / 验收裁决（verify） | Opus | — |
| 安全 / 评审 / 对抗复核（security / code_review / adversarial_review） | Opus | — |
| UX / API / 前端**设计决策**（ux_design / api_design / frontend_ui，plan 期） | Opus | — |
| 上述领域的**实现**（implement 期） | Composer | 连续失败 / 返工 → Opus |

**运转日志中的「模型」字段**（与上表路由档分离）：
- `run-log.sh phase --model` 必须填**本次对话实际模型 ID**（如 `gpt-4.1`），**禁止**把上表「Opus/Composer」
  路由档名当日志值（Copilot 用 GPT 时写 Opus 即造假）。
- 可 `export SPECKIT_MODEL='<实际模型>'`；省略 `--model` 时由脚本按 `SPECKIT_RUNTIME` / 环境推断。
- Cursor → 填界面显示的模型；Copilot → 填所选 GPT 型号。

## 维度激活与缺口处理（Dimension Activation & Gap Handling）

每个阶段开始时，编排层按 `.cursor/registry.yaml` 的 `bind_phase` 查表，
激活该阶段对应维度的本地 skill。

**条件维度**（带 `when:` 的专业领域维度）默认休眠，仅在命中条件后激活：
`ux_design` 由 specify/clarify「是否有 UI 需求」触发，其余领域维度由 plan 技术栈闸门触发；
`analyze` 复核「已激活的领域维度与技术栈一致，无漏挂/误挂」。

注册表未命中某维度时，**必须先暂停并询问用户**「该维度是否需要专门 skill？」，
不得由 AI 自行决定是否降级或联网：

- 用户答「需要」→ 进入**补全路径**（联网发现 / 用户指定 / 现场编写后登记），
  经审查门后固化进注册表，**不进入三层降级**。
- 用户答「不需要」→ 才进入**三层降级**：
  1. 泛化兜底（已有通用 skill + Opus 知识）
  2. Opus 现场生成一次性 checklist 注入本阶段
  3. 降级链上的联网补全（最后手段，需二次确认）

详见 `.cursor/rules/workflow-orchestration.mdc`。

## 联网补全护栏（Supplement Guardrails）

任何联网/补全（含补全路径与降级链第 3 层）必须满足：
1. **用户闸门优先**：未命中先问，降级链联网须二次确认。
2. **可信源优先**：优先官方 / 高星 / 已知来源；记录 origin。
3. **审查门 + 降权**：候选先入 `.cursor/quarantine/`，仅作「参考资料」降权使用，
   不以可执行指令身份运行；经评分与人工确认后才提级到 `.cursor/skills/` 或注册表。
4. **固化复用**：通过后写入注册表（source: discovered），下次同维度直接命中，不再联网。

## 技术栈与运行方式闸门（Tech-Stack Gate · 进入 plan 前必做）

技术栈/架构是**方向性决策**（归用户，见 Principle III），不是可由 AI 默认带过的口味题。
因此 **进入 `plan` 之前必须先暂停，与用户确认技术栈与架构方向**，确认前禁止撰写 plan。

- **必须摆给用户的关键岔路**（至少覆盖以下，按需增减）：
  1. 形态：纯前端 / 全栈（含后端） / 仅脚本或 CLI
  2. 是否需要账号与登录、权限
  3. 是否需要持久化与多端同步（本地存储 vs 数据库 vs 云）
  4. 运行/部署方式：双击打开 / 本地 server / 托管部署
  5. 框架与语言倾向（若用户无偏好，AI 给出带理由的推荐供其确认）
- **禁止**把上述方向决策默默写进 spec 的 Assumptions 一带而过。
- 用户给出明确技术栈 → 直接采用；用户说「你定」→ AI 推荐并**简述理由后仍需用户点头**。
- **运行方式可行性自检**：所选技术栈必须与承诺的运行方式相容。
  例：选 ES Module 则不能承诺 `file://` 双击运行（浏览器会拦截），
  必须改为本地 server 或改用经典脚本/打包。此项由 `analyze` 阶段强制核对。
- **闸门结论决定条件领域维度**：确认的形态/栈同时决定激活哪些条件维度
  （后端→`api_design`、前端→`frontend_ui`、需持久化→`data_modeling`、GCP→`gcp_runtime` 等）。

## 复杂度分级与快速通道（Triage & Fast-Track）

并非每个改动都值得全流水线。`specify` 起始按下述判据给出 `stack.complexity`
（`trivial | standard | complex`），写入特性目录 `stack.yml`：

- **trivial 判据（须全部满足）**：单一关注点；无账号/登录；无超出本地的持久化；
  可回滚；不接外部 API；不引入新架构方向。
- 任一不满足 → 至少 `standard`；涉及架构/迁移/多模块/不可逆 → `complex`。

**快速通道（仅 trivial）**：
- 跳过 `clarify` 的提问环节（仍**自动扫描** spec 残留模糊点，`gate-clarify.sh` 照跑）。
- 跳过 `analyze` 的硬 checklist 完整流程，走**轻量核对**。
- **仍必须过 `verify`**（按 form 选轻量档），「验证而非声称」红线对 trivial 同样不可豁免。
- 技术栈闸门：trivial 若沿用既有栈可**免暂停确认**，但 `stack.yml` 仍要写明并 `confirmed: true`。

**standard / complex 走全流水线**（含技术栈闸门暂停确认、analyze 硬 checklist）。
用户可随时手动升/降档；拿不准时**默认按更高档**处理（宁可严，不放水）。

## 可执行门（Executable Gates · 退出码即真相）

红线不只写在文里，关键项由 `.specify/scripts/bash/` 下脚本**机械判定**，非零退出即拦截：

- `gate-charter.sh`：charter 结束；`charter.yml` 已 `confirmed: true` + `charter.md` 非模板。进 specify 前须 PASS（P0/unlock，不在 specify 重复登记）。
- `gate-global-prefs.sh`：specify 结束 / 进 plan 前校验环境隔离已用户确认（`global-prefs.yml` 或 legacy `stack.yml`）。
- `gate-spec-coverage.sh`：specify 结束 / 进 plan 前校验 Post-Draft Ping（`spec-coverage.yml`、Input Q&A、Assumptions 标签、非模板占位）；delegate `gate-global-prefs`。
- `gate-clarify.sh`：进 plan 前扫 spec 残留 `[NEEDS CLARIFICATION]`/TODO，并 delegate 覆盖度门。
- `gate-stack.sh`：校验 `stack.yml` 存在且 `confirmed: true`、有 `form:`。
- `activate-dimensions.sh`：读 `stack.yml`+registry，**确定性**输出该激活的条件维度。
- `gate-analyze.sh`：聚合（无模糊点 / 覆盖度 / 栈已确认 / plan.md 存在 / 用户故事在 tasks 有落点 / 激活维度路径可解析）。
- `gate-verify.sh`：跑 `verify.yml` 声明的命令看退出码、扫残留、按 `form` 选 DoD 档位。

脚本只做**可机械判定**的检查；主观质量（一致性、品味、根因）仍由 Opus 判断，
但不再以"门"自居。门与人工判断**互补**，缺一不可。

## verify 阶段与可执行 DoD（Verify Phase & Executable Definition of Done）

implement 完成后**必须**进入 `verify` 阶段（本工作流自有阶段，非 speckit 原生命令）。
由编排层**亲自**执行，**不接受自我汇报**。**DoD 按产物形态选档**
（web/cli/service/library/pipeline，见 `.specify/memory/verify-profiles.md`）：
`gate-verify.sh` 跑 `verify.yml` 声明的命令看退出码并按 `form` 选档；
**chrome-devtools(-cli) 仅 web 档必需**，其余形态用各自命令验证：

**可执行 DoD（逐条留证据，缺一不可）**：
1. **真能启动**：用 plan 承诺的运行方式实际启动产物（双击 / 本地 server / 部署）。
2. **零报错**：打开后浏览器/运行时 console 无 error（这一条即可抓出"空白页"类问题）。
3. **验收场景全过**：spec 的每条 Acceptance Scenario 实际执行一遍，记录通过/失败。
4. **三态可见**：空态 / 加载 / 错误态分别截图或描述确认存在。
5. **UX 红线核对**：交互形态符合 plan（如该弹窗就不是内联）、关键流程（如登录）在位。
6. **无残留**：无 TODO / stub / 空函数 / 占位实现。
7. **测试真跑**：声称的测试必须**真实运行**并通过，而非"应当通过"。

任一未过 → 回到 implement 修复后**重跑 verify**；不得跳过或降低标准。
证据汇总写入特性目录的 `verify.md`。

## 交付与发布范式（Deliver & Release · verify 之后，不替代 verify）

当 `stack.yml.release.enabled: true` 时，「合并/MR」与「上线」因**频率/触发/粒度不同**分为两个环节
（对应 deploy ≠ release、Continuous Delivery ≠ Continuous Deployment）：

- **deliver（交付）**：跟 MR 节奏，每个 feature `verify` 通过后**可自动跟**——PR → CI 绿 → 合并 main → staging。
  per-feature，证据 `specs/<feature>/deliver.md`，门 `gate-deliver.sh`。
- **release（上线）**：**仅用户显式要求**才执行，低频，**可聚合多个已交付 feature** 渐进发布到生产 + 回滚 + 取证。
  仓库级 `.releases/<version>/release.md` + `RELEASES.md` 账本，门 `gate-release.sh`。

**边界**：verify 管「产物对不对」→ deliver 管「合进 main、到 staging」→ release 管「上没上去生产 + 能否回滚」。三者不可互相替代。
**上线只由用户触发**，不得在 verify/deliver 后自动上生产（呼应 Principle III：方向决策归用户）。

范式综合业界优秀实践（DORA / Progressive Delivery / trunk-based / GitHub Environments / expand-contract /
feature flags / 自动回滚），按**成熟度档** `tier`（T0 最小合规 → T3 精英）选 DoD，详见 `.specify/memory/release-profiles.md`。
七条核心原则不可违背：① 小批量+短命分支+频繁合并；② 解耦部署与发布（feature flags）；③ 不可变制品（一次构建、多处部署、SHA）；
④ **自动回滚优先于自动部署**；⑤ 渐进暴露+SLI 闸（T2+）；⑥ **expand-contract 迁移**（先扩后缩、每阶段可回滚）；
⑦ 全程取证/部署标记（timestamp+git_sha+outcome，可算 DORA 五指标）。

**可执行 DoD**：制品可追溯（SHA）、健康检查取证（退出码为准）、**回滚路径存在**、部署标记；release 还须 includes 的
每个 feature 都已 deliver。`gate-deliver.sh` / `gate-release.sh` 机械判定，证据落对应文件（不留「待发/待验/待上线」）。
**失败判据**：deliver 失败回 implement→verify→重 deliver；release 失败回 release 修后重跑；上线暴露功能 bug 则回
implement→verify→deliver→再 release。外部发布工具（gstack `/ship` 等）**不替代**本环节、不得绕过取证。
`speckit-release` 同时是**生成器**：为新项目按策略产出专属 `deploy/` 脚本。

## 迭代与维护再入（Iteration & Maintenance Re-entry · 已交付/已上线后的变更）

流水线不是一次性单程。当一个**已过 verify / 已交付 / 已上线**的特性，被用户报告功能 bug 或提出
变更/改进时（如 `002` 笔记 App 的「点新建无反应」），**不从零新开 specify**，而是 **amend 既有特性**：
复用其 `spec.md` / `plan.md` / `stack.yml`，只动受影响的部分。触发是**用户驱动**（方向归用户）。

按改动性质三分级（拿不准默认按更高档）：

- **缺陷修复（bug fix）**：用 `debugging`(diagnose) 维度定位根因 → 外科式修复 → **必过 verify**：
  重跑受影响的 Acceptance Scenario，并**新增一条防复发的验收/回归项**（呼应 002 教训），证据追加到 `verify.md`。
  若验收场景本就漏了该情形，先把它补进 spec 的 Acceptance（否则改了代码却没有任何场景守住它）。
- **小改进 / 变更请求（change request）**：先**更新 spec 的相关条目**（记为变更，不重写整份）→ 按改动幅度
  **局部**重过 clarify/plan/analyze 的相关子步骤（不整条重跑）→ implement → **必过 verify**。
- **大改 / 架构级 / 不可逆**：当作 `complex` 新特性走全流水线（可在新特性里引用旧特性）。

**再入红线（不可豁免）**：
1. **任何再入都必须重过 verify**——「验证而非声称」对维护同样不打折，gate-verify 照跑。
2. **行为变更先改 spec 再改码**：禁止「代码改了、spec/验收不改」的漂移（一致性红线的延伸）。
3. **修 bug 必补防复发项**：缺陷暴露的场景必须沉淀为一条新的验收/回归，防止同类问题再次发生。
4. **触发再发布则回发布范式**：已上线特性的变更若需重新发布，按 deliver→release，**回滚路径先于部署**。

## AI 驱动推进（Drive · meta 模式）

`/speckit-drive` 是**编排壳**，不是第 11 个 P1 阶段。详见 `.specify/memory/orchestration/iteration-drive.md`。

- **greenfield**：`drive.yml` 须 `consent: true` 且 `auto_advance: true` 方可在 **pause_at 以外**的闸门之间自动 invoke 下一 `speckit-*` 阶段；**charter 确认、环境隔离、技术栈确认、verify 需人项、release** 必须暂停等用户。
- **maintain**：交付后 **pulse**（一次一问）→ 可选 **iteration-queue** → 用户显式要求才 **amend→verify**；不得无人回复自动改码。
- **scheduled pulse**（`.specify/pulse-schedule.yml` + Cursor Automation）：仅 **采集**体验/需求（`pulse-log.md`）；`check-pulse-schedule.sh` 不通过则静默退出；`record-pulse-run.sh` 维护周期配额。
- Drive **不得**覆盖阶段门、不得替代 `verify.md` 证据、不得自动 release。

## 质量红线（Quality Redlines · 自动补齐，不询问用户）

- 零模糊点：spec 无 `[NEEDS CLARIFICATION]` 且 `gate-spec-coverage.sh` PASS 才进 plan。
- 技术栈已确认：未经用户确认技术栈/架构方向，不得进入 plan。
- 功能不漏：analyze 阶段交叉核对每条用户故事的落点。
- 运行方式可行：analyze 阶段核对技术选型与承诺的运行/部署方式相容。
- **验证而非声称**：未过可执行 DoD 的产物，一律视为未完成。
- 一致性优先：术语、交互、数据模型与既有保持一致。
- 能力固化：联网产物必须固化（锁定来源/版本）后才用；流程/能力集合可复现，**不承诺 LLM 逐字可复现**。
- 可回滚：不可逆改动须先有回滚方案。
- **外科式变更（implement 期实时约束）**：只改与当前任务直接相关的代码；不顺手「优化/美化」相邻代码、不重构未坏的部分、匹配既有风格。每行改动都应能追溯到 spec/tasks 的某条需求。越界的改进先记为待办，不夹带进本次实现。

## Governance

本宪法优先于所有阶段 skill 的默认行为与「讨好式同意」的本能。
修订须更新版本号与日期，并同步更新 `ARCHITECTURE.html`。
各阶段执行前应核对：是否遵守模型路由、是否触发用户闸门、是否过技术栈闸门、
是否守住质量红线、是否通过 verify 阶段的可执行 DoD。

**Version**: 1.13.0 | **Ratified**: 2026-06-02 | **Last Amended**: 2026-06-05
<!-- v1.13.0: meta drive（speckit-drive）+ pulse-schedule Automation + gate-drive；不新增 P1 阶段 -->
<!-- v1.12.0: charter 阶段 + gate-charter.sh + charter.md/yml；abc/业务逻辑迁出 specify；gate 仅 charter.gates_before_next 登记一次 -->
<!-- v1.11.0: gate-global-prefs.sh + global-prefs.yml（specify 开场硬序①；无 FEATURE_DIR 也要先问）；gate-spec-coverage/clarify delegate；create-new-feature 种子模板 -->
<!-- v1.10.0: gate-spec-coverage.sh + spec-coverage.yml（Post-Draft Ping 机械门）；gate-clarify 聚合覆盖度；gate-stack ⑤ Q&A；gate-analyze 查 plan.md；Assumptions [ASSUMPTION]/[CONFIRMED] -->
<!-- v1.8.0: 发布范式拆为 deliver(交付·跟 MR 自动·per-feature)+ release(上线·仅用户触发·聚合多 feature·仓库级账本)两环节;新增 gate-deliver.sh + deliver-template.yml;gate-release.sh 改仓库级 .releases/<version>/(校验 includes 都已 deliver);registry 拆 delivery+release 维度;上线只由用户触发不自动上生产 -->
<!-- v1.7.0: 新增「release 阶段与发布范式」(verify 之后、不替代 verify) + release-profiles.md(7 原则/6 阶段/T0–T3/回滚矩阵) + gate-release.sh + speckit-release 维度(编排+生成器) + stack.yml release 段;综合 DORA/Progressive Delivery/trunk-based/GitHub Environments/expand-contract/feature flags/自动回滚 -->
<!-- v1.1.0: 新增「技术栈与运行方式闸门」+ 两条质量红线（技术栈已确认 / 运行方式可行） -->
<!-- v1.6.0: 新增原则 VII「环境隔离」+ 冲突裁决链追加「全局偏好」最低优先级 + 环境隔离闸门（specify 起始，决策记入 stack.yml.global_prefs） -->
<!-- v1.6.1: run-log --model 须记实际模型 ID,禁止用 Opus/Composer 路由档冒充;Copilot/GPT 与 Cursor 分记 -->
<!-- v1.5.0: 新增质量红线「外科式变更」（吸收 andrej-karpathy-skills 的 Surgical Changes；其余 3 条已被 first-principles/clarify 闸门/TDD/verify 覆盖，不整体引入以免指令稀释） -->
<!-- v1.2.0: 新增原则 II-bis「验证而非声称」+ verify 阶段与可执行 DoD + verification 维度 + 验证用 Opus -->
<!-- v1.3.0: 新增原则 VI「增强而非替换」+ 增强层（Addy/Superpowers/Matt）6 通用 + 10 条件领域维度 + 冲突裁决 + 条件维度激活 + 模型路由补充 -->
<!-- v1.4.0: 可执行门（gate-*.sh 退出码即真相）+ 机器可读 stack.yml 驱动条件维度激活 + 复杂度分级与快速通道 + verify DoD 按 form 选档（verify-profiles.md）+ 修正「可复现」过度声称（LLM 非确定，固化的是流程/能力集合）+ 原则 II 改为「可控与能力固化」 -->

