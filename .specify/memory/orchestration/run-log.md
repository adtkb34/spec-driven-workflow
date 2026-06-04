# 运转日志（Run Log）

目的：让用户**事后核对**工作流真实运转。日志落在 `FEATURE_DIR/run-log.md`，由 `run-log.sh` 追加。
**核心原则：分清机械证据与自述**。

- **GATE 行 = 机械证据**：gate 脚本 EXIT trap 自记，编排层无法篡改。
- **PHASE 块 = 自述 + 产物机械核验**：每 speckit 阶段**结束时必调用**：

```bash
.specify/scripts/bash/run-log.sh phase \
  --phase <阶段名> \
  --model "<实际模型 ID>" \
  --skills "<实际 Read/执行的 skill>" \
  --skills-skipped "<命中但未 Read 的维度,可选>" \
  --scripts "<本阶段脚本,逗号分隔>" \
  --artifacts "<相对 FEATURE_DIR 的产物>" \
  --note "<一句话>"
```

**`--skills` 硬约束**：
- 仅列**实际 Read SKILL.md 并执行**的 skill；禁止把 registry bind_phase 整包误报。
- 渐进披露：只注入 D1 summary 未 Read 全文 → 写 `--skills-skipped`，勿写 `--skills`。
- 深度格式：`{skill}[full|partial:<简述>]`。

**`--model`**：填本次会话真实模型 ID，禁止写路由档位名 Opus/Composer。

**硬约束**：PHASE 自述不能替代 verify 证据；阶段结束未写 run-log = 未走完，不得进下一阶段。

`run-log.sh phase` 会同步更新 `phase.yml` 的 `current_phase` 与时间戳。
