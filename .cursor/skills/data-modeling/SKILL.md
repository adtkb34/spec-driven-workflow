---
name: data-modeling
description: >-
  Designs persistent data models: entities and relationships, schema, indexing,
  migrations, query patterns, and consistency/transaction boundaries—platform-agnostic
  (SQL or NoSQL). Use when a project needs persistence or a database, when defining or
  changing schema, when write/read patterns or performance hinge on the data layer, or
  when planning a data migration. Triggers: 数据建模/持久化/数据库/schema/表结构/索引/迁移/范式。
---

# Data Modeling（数据建模 / 持久化）

支撑 `data_modeling` 维度（registry，`when: 需要持久化/数据库/schema`，`bind_phase: [plan, tasks, implement]`）。
现场编写（`origin: authored`），平台无关，SQL / NoSQL 通用。

## Quick start

1. **先实体再存储**：从 spec 的名词/用户故事抽出**实体、属性、关系（1:1 / 1:N / N:N）与基数**，画一张概念模型，再谈用哪种库。
2. **由查询驱动 schema**：列出关键**读写访问路径**（谁按什么字段查、写入频率、一致性要求），让访问模式决定规范化程度与索引，而不是反过来。
3. **定边界**：明确**事务边界**与**一致性级别**（强一致 vs 最终一致）、唯一约束、外键/引用完整性策略。
4. **可演进**：所有结构变更都走**版本化迁移**，且**先写回滚**（呼应 constitution「可回滚」）。
5. **落 plan**：把数据模型、关键索引、迁移与回滚策略写进 `plan.md`，供 tasks 拆解与 implement 执行。

## 设计决策清单（plan 阶段逐条过）

- **库选型**：关系型（事务/复杂查询/强一致）vs 文档/KV（弹性 schema/水平扩展/读多写少）vs 两者混用；给出理由，与技术栈闸门结论一致。
- **规范化 vs 反规范化**：默认规范化到 3NF；仅在有**实测**读放大或热点时按访问路径反规范化，并记录代价（写一致性、冗余）。
- **主键**：自增 vs UUID/ULID（分布式、避免热点、可外部生成）；不要把业务字段当主键。
- **索引**：为每条高频查询路径设计索引；覆盖索引、复合索引列序（等值在前、范围在后）；警惕过度索引拖慢写入。
- **关系**：N:N 用连接表；软删除 vs 硬删除；级联策略明确。
- **时间与审计**：`created_at`/`updated_at`、是否需要软删除/版本/审计日志。
- **大对象与枚举**：BLOB/文件走对象存储存引用；枚举用受约束类型，避免裸字符串漂移。

## 迁移纪律（implement 阶段）

- 每次变更一个**前向迁移 + 一个回滚**，可重复执行（幂等）。
- **扩展-收缩（expand/contract）**：加列→双写/回填→切读→删旧列，避免破坏性一步到位。
- 大表变更评估锁与时长；必要时分批回填。
- 迁移在**类生产数据量**上演练过再上；回滚路径必须真验证。

## 与 verify 的衔接

- verify 阶段须实跑：迁移可正向应用**且可回滚**；关键查询有预期索引命中（`EXPLAIN`/执行计划）；约束（唯一/外键/非空）真实生效。
- 「测试真跑」覆盖数据层：建/查/改/删与边界（空表、重复键、并发写）。

## 红线（命中即整改，不绕过）

- ❌ 无访问路径分析就定 schema（凭感觉建表）。
- ❌ 破坏性迁移无回滚方案。
- ❌ 把可空、无约束、无索引当默认。
- ❌ 用应用层 join 替代本该建模的关系而不评估代价。
- ❌ 敏感字段（密码/令牌/PII）明文落库——交由 `security-and-hardening` 维度核对加密/脱敏。

## 与其它维度分工

- `api_design`：对外契约与边界校验；本 skill 管**落库**的内部模型，两者在边界对齐字段语义。
- `improve-codebase-architecture`（architecture 维度）：宏观分层；本 skill 聚焦数据层细节。
- `gcp_runtime` / `cloud-sql`/`bigquery` 等：选定具体托管库后，由对应领域 skill 补平台细节。
