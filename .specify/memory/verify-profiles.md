# Verify 档位（DoD Profiles by Product Form）

`verify` 阶段的可执行 DoD **按产物形态选档**。形态来自 `FEATURE_DIR/stack.yml` 的
`form:`（或 `verify.yml` 覆盖）。`sync-verify.sh` 从 spec/tasks 生成 `verify-coverage.yml` 并合并
`verify.yml`（防漏测项）。`gate-verify.sh` 跑 `verify.yml` 声明的命令、看退出码、检查与 coverage 对齐、
扫残留，并打印本档位；**AI/Opus 仍需按 coverage 的 US 清单实跑 GUI** 并写入 `verify.md`。
对齐协议见 `verify-sync.md`。

> chrome-devtools(-cli) 仅 **web 档** 必需；其余形态用各自的命令验证，不强行套浏览器。

## 测试主导权（所有形态通用 · 硬约束）

**AI 主导测试，人只审报告。** 顺序：
1. **AI 优先自动**：凡能脚本化/可编程驱动的（命令、HTTP、CLI、headless 浏览器、WebDriver、截图）AI **一律自己跑**，把证据写进 `verify.md`。
2. **AI 截图判断**：视觉/交互类（三态、布局、UX）AI 先**自动截图**再判断；能判定就判定。
3. **需人辅助（例外，能少则少）**：仅当 AI 客观无法完成时——需要凭证/密钥、外部设备、人脸/验证码、主观体验裁决、或自动化环境缺失——AI 必须：
   - 在 `verify.md` 把该项标 `需人辅助` + **原因** + **给人的最小操作步骤**；
   - **暂停并显式叫人**（不要静默跳过，也不要假装通过）；
   - 人给出结果后，AI 回填 `人工确认: …` 并把该项结案（✓ / - [x]）。
4. **人审报告**：人只需读 `verify.md`（机械门退出码 + 验收/边界/专项结果 + 需人项确认），不必逐个手测。

`gate-verify.sh` 强制：所有验收/边界/专项项必须**结案**；`需人辅助` 项缺 `人工确认` = FAIL；不得留「待跑/待 GUI」。

## 覆盖完整性（sync-verify 自动生成，不靠人记）

`sync-verify.sh` 从 spec/tasks 生成 `verify-coverage.yml`，覆盖三类，逐条进 `verify.md`：
- **功能验收**：spec 每条 User Story（US1…USn）。
- **边界与异常**：spec `### Edge Cases` 每条（EDGE-n）。
- **形态专项 DoD**：下方各档清单（PF-n），按 `form` 自动注入。

## 通用底线（所有档位都要过）

- **真启动 / 真运行**：用 plan 承诺的方式实际跑起来，不是 dry-run。
- **零硬报错**：启动/运行过程无未处理异常、无致命错误。
- **验收全过**：spec 每条 Acceptance Scenario 实跑一遍并记录结果。
- **无残留**：声明的 `scan_paths` 内无 stub / 占位实现 / 空函数 / TODO 实现。
- **测试真跑**：声称的测试实际执行并通过（退出码 0）。
- 证据（命令、退出码、关键输出/截图）落到 `verify.md`。

## web

**AI 自测手段**：`chrome-devtools-cli`（纯 shell，降级 MCP）打开页面、抓 console、点路由、**截图**判断三态/UX；E2E（Playwright 等）纳入 `verify.yml` 并**把截图写到 `verify-artifacts/`**，再在 `verify.md` 引用该文件路径（gate 校验文件存在 → 视觉项不再是自述）。**需人辅助仅限**：外部登录凭证、支付/验证码、纯主观视觉裁决。

```yaml
# verify.yml 片段：E2E 产出可校验产物
commands:
  - name: e2e
    run: "cd app && npx playwright test --reporter=line"   # 配置截图输出到 ../specs/<feat>/verify-artifacts/
```

- `gate-verify.sh` 跑 build/test 命令为绿。
- chrome-devtools-cli 实际打开页面：**console 零 error**（抓"空白页"类问题）。
- **三态可见**：空 / 加载 / 错误态确认存在（截图或描述）。
- **UX 红线**：交互形态符合 plan（该弹窗不内联）、关键流程（如登录）在位。
- 关键路由/页面可达，无 404/白屏。

## desktop（Tauri / Electron 等原生壳 + WebView UI）

> 凡 `stack.yml` 的 `form` 为 `desktop`，或 plan 明确为 Tauri/Electron 桌面 GUI，**不得**仅用 `cli` 档代替本档。

**AI 自测手段**：① Rust/前端单测 + 集成测试覆盖 commands/持久化（AI 全自动）；② Tauri **WebDriver**（`tauri-driver` + WebdriverIO/`selenium`）驱动真窗口、点按钮、**截图存 `verify-artifacts/`**，`verify.md` 引用该截图（gate 校验存在）；③ 启动后抓终端日志判 panic。**需人辅助仅限**：本机无 WebDriver/无头环境时的最终视觉确认。

```yaml
# verify.yml 片段：tauri-driver E2E
commands:
  - name: e2e-desktop
    run: "cd app && npm run e2e"   # WebdriverIO + tauri-driver；截图 → ../specs/<feat>/verify-artifacts/
    optional: true                 # 慢/需驱动；VERIFY_FULL=1 时跑
```

- `gate-verify.sh` 跑 build/test 命令为绿（与 web 相同）。
- **真启动 GUI**：`tauri dev` 或打开打包后的 `.app` / `.exe`，窗口出现且无白屏。
- **WebView 交互红线（必查）**：
  - 禁止依赖 `window.prompt` / `alert` / `confirm`（Tauri/WKWebView 常静默失败）；
  - 新建/删除等主流程必须用应用内 Dialog。
- **spec Acceptance Scenarios** 逐条实点（新建笔记本、新建笔记、搜索、预览模式切换、重启后数据仍在）。
- 控制台/终端无未处理 Rust panic；WebView devtools 无 error（能开则抓）。
- 三态可见：无数据 / 有数据 / 错误提示（如顶部 error banner）。

## cli

**AI 自测手段**：完全可自动——AI 直接 spawn 进程，断言 stdout/stderr/退出码，喂边界输入。**通常无需人。**

- 跑二进制 / 入口：`--help` 正常输出用法。
- 正常路径：给定输入产出预期 stdout，退出码 0。
- 错误路径：非法输入有清晰报错且**退出码非 0**（错误码语义正确）。
- 边界输入：空输入 / 超长 / stdin 管道 / 不存在的文件等不崩溃。

## service / api

**AI 自测手段**：完全可自动——AI 启动服务、`curl`/HTTP 客户端打健康检查与关键端点、校验 status/body/契约、构造未授权与 4xx/5xx 用例。**通常无需人**（除非依赖外部真实凭证/三方沙箱）。

- 启动服务进程并通过**健康检查**（如 `/healthz` 200）。
- 关键端点逐个实跑：正常请求返回预期 status/body。
- 错误语义：4xx/5xx 在该返回时返回，契约（schema/字段）一致。
- 鉴权端点未授权时正确拒绝（呼应 security 维度）。

## library

**AI 自测手段**：完全可自动——AI 跑测试套件、按 README/示例写冒烟脚本调用公共 API、校验签名与文档一致。**通常无需人。**

- 测试套件全绿（单元 + 关键集成）。
- 公共 API 冒烟：按 README/示例调用主路径成功。
- 示例 / quickstart 代码可跑（不是仅文档）。
- 公共接口签名与文档/契约一致（无意外 breaking）。

## pipeline

**AI 自测手段**：完全可自动——AI 用样本输入端到端跑、校验输出 schema/行数/字段、重跑验幂等、检查失败日志。**通常无需人**（除非依赖外部数据源凭证）。

- 用**样本输入**端到端跑通，产出非空。
- 输出 **schema / 行数 / 关键字段**校验通过。
- 幂等 / 可重跑：重复运行不产生脏数据或重复写入（如适用）。
- 失败可观测：异常有日志、可定位失败步骤。

## unknown（未声明 form）

- 至少满足「通用底线」全部项；强烈建议回 plan 在 `stack.yml` 补 `form:`。

---

### `verify.yml` 最小示例（放 FEATURE_DIR）

优先运行 `sync-verify.sh` 从 spec/tasks 自动生成/合并；手工只补 `optional: false` 的自定义命令。

```yaml
form: web
commands:
  - name: build
    run: "npm run build"
    auto_sync: true
  - name: test
    run: "npm test"
    auto_sync: true
scan_paths: ["src"]
acceptance: []   # 由 sync 从 spec User Stories 填充
```

发布前可选：`VERIFY_FULL=1 gate-verify.sh` 执行 `optional: true` 的慢命令（如 `tauri build`）。
