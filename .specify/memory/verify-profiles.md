# Verify 档位（DoD Profiles by Product Form）

`verify` 阶段的可执行 DoD **按产物形态选档**。形态来自 `FEATURE_DIR/stack.yml` 的
`form:`（或 `verify.yml` 覆盖）。`gate-verify.sh` 跑 `verify.yml` 声明的命令、看退出码、
扫残留，并打印本档位；**人工/Opus 仍需按本档补齐不可机械判定的验收项**并写入 `verify.md`。

> chrome-devtools(-cli) 仅 **web 档** 必需；其余形态用各自的命令验证，不强行套浏览器。

## 通用底线（所有档位都要过）

- **真启动 / 真运行**：用 plan 承诺的方式实际跑起来，不是 dry-run。
- **零硬报错**：启动/运行过程无未处理异常、无致命错误。
- **验收全过**：spec 每条 Acceptance Scenario 实跑一遍并记录结果。
- **无残留**：声明的 `scan_paths` 内无 stub / 占位实现 / 空函数 / TODO 实现。
- **测试真跑**：声称的测试实际执行并通过（退出码 0）。
- 证据（命令、退出码、关键输出/截图）落到 `verify.md`。

## web

- `gate-verify.sh` 跑 build/test 命令为绿。
- chrome-devtools-cli 实际打开页面：**console 零 error**（抓"空白页"类问题）。
- **三态可见**：空 / 加载 / 错误态确认存在（截图或描述）。
- **UX 红线**：交互形态符合 plan（该弹窗不内联）、关键流程（如登录）在位。
- 关键路由/页面可达，无 404/白屏。

## cli

- 跑二进制 / 入口：`--help` 正常输出用法。
- 正常路径：给定输入产出预期 stdout，退出码 0。
- 错误路径：非法输入有清晰报错且**退出码非 0**（错误码语义正确）。
- 边界输入：空输入 / 超长 / stdin 管道 / 不存在的文件等不崩溃。

## service / api

- 启动服务进程并通过**健康检查**（如 `/healthz` 200）。
- 关键端点逐个实跑：正常请求返回预期 status/body。
- 错误语义：4xx/5xx 在该返回时返回，契约（schema/字段）一致。
- 鉴权端点未授权时正确拒绝（呼应 security 维度）。

## library

- 测试套件全绿（单元 + 关键集成）。
- 公共 API 冒烟：按 README/示例调用主路径成功。
- 示例 / quickstart 代码可跑（不是仅文档）。
- 公共接口签名与文档/契约一致（无意外 breaking）。

## pipeline

- 用**样本输入**端到端跑通，产出非空。
- 输出 **schema / 行数 / 关键字段**校验通过。
- 幂等 / 可重跑：重复运行不产生脏数据或重复写入（如适用）。
- 失败可观测：异常有日志、可定位失败步骤。

## unknown（未声明 form）

- 至少满足「通用底线」全部项；强烈建议回 plan 在 `stack.yml` 补 `form:`。

---

### `verify.yml` 最小示例（放 FEATURE_DIR）

```yaml
form: web
commands:
  - name: build
    run: "npm run build"
  - name: test
    run: "npm test"
scan_paths: ["src"]
```
