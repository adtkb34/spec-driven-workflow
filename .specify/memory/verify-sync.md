# Verify 自动对齐 + AI 主导测试（spec / tasks → verify.*）

## 一句话

**AI 主导测试，人只审报告。** 验证内容由 `sync-verify.sh` 从 spec/tasks **自动生成完整清单**，
AI 能自动测的全自动测，真需要人时**显式叫人辅助、确认后再结案**；`gate-verify.sh` 机械兜底，不许漏、不许静默跳过。

## 三个文件

| 文件 | 谁维护 | 内容 |
|------|--------|------|
| `verify-coverage.yml` | **机器**（`sync-verify.sh`） | 从 spec/tasks 推导的应测全集：命令 + US 验收 + Edge Cases + 形态专项 DoD（含每项 `owner`） |
| `verify.yml` | **机器合并 + 人可追加** | `gate-verify` 实际执行的命令；`acceptance:` 镜像 US 列表 |
| `verify.md` | **AI 填（人辅助时补确认）** | 测试报告：机械门退出码 + 验收/边界/专项逐条结果与证据 |

## 覆盖完整性（不靠人记，三类全收）

`sync-verify.sh` 自动抽取并要求逐条结案：
1. **功能验收** US1…USn —— spec User Stories。
2. **边界与异常** EDGE-1…n —— spec `### Edge Cases` 每条。
3. **形态专项 DoD** PF-1…n —— 按 `form`（web/desktop/cli/service/library/pipeline）注入（见 `verify-profiles.md`）。

## owner：谁来测（默认 AI）

| owner | 含义 | 例子 |
|-------|------|------|
| `ai-auto` | AI 全自动跑，退出码/断言即证据 | 命令、CLI、HTTP、单测、FTS、schema 校验 |
| `ai-visual` | AI 自动**截图后判断**；拿不准才升级需人 | 三态、布局、白屏、UX |
| `needs-human` | AI 客观无法完成，**显式叫人** | 凭证/密钥、验证码、设备、主观裁决 |

非 GUI 形态的 US 默认 `ai-auto`；GUI 形态默认 `ai-visual`。

## 人机协议（一定需要人时）

AI 不得静默跳过或假装通过。需人时在 `verify.md` 写：

```text
- [ ] (PF-2) [需人辅助] 真启动 GUI 无白屏 — 原因: 本机无 WebDriver；步骤: 双击 .app 看是否出窗口 — 人工确认: 
```

然后**暂停叫人**；人给结果后 AI 回填 `人工确认: <结果>` 并改 `- [x]`（或验收行 ✓）。
`gate-verify` 检查：标了 `需人/待人工` 却无 `人工确认` → FAIL。

## 何时跑

| 时机 | 命令 |
|------|------|
| `tasks` 阶段结束 | `sync-verify.sh` |
| `implement` / `verify` 前 | `sync-verify.sh` |
| `gate-verify.sh` 内 | 自动 `sync` → 跑命令 → `--check` 对齐 + 结案检查 |
| 发布前完整档 | `VERIFY_FULL=1 gate-verify.sh`（跑 `optional: true` 慢命令，如 `tauri build`） |

## 视觉项防自述（ai-visual · 硬约束）

GUI/视觉项的「✓」不能只写一段话——`gate` 要求该行**引用真实存在的产物文件**
（截图/E2E 报告，约定放 `FEATURE_DIR/verify-artifacts/`，如 `verify-artifacts/us1.png`），
或显式转 `需人辅助` 并补 `人工确认: …`。否则 FAIL。
让视觉项变机器可校验的正路：在 `verify.yml` 接 E2E（web→Playwright；desktop→tauri-driver），
E2E 跑出截图写进 `verify-artifacts/`，`verify.md` 引用之 → `ai-visual` 实质升级为 `ai-auto`。

## 复杂度分档（读 stack.yml 的 complexity）

| tier | 强制范围 |
|------|----------|
| `trivial` | US + PF（EDGE 仅列出、软提示） |
| `standard` / `complex` | US + EDGE + PF 全硬性 |

## 抽空即报警（防假绿）

spec 含 `### User Story` / `### Edge Cases` 区块却解析出 0 条（格式漂移）→ `gate` 直接 FAIL，
**不会**因「没东西可查」而假装通过。

## gate-verify 会 FAIL 的情况（机械兜底）

- `verify.yml` 缺 coverage 要求的命令；
- 覆盖解析异常（区块在但抽空）；
- 任一 US 验收行空白 / 待跑 / 非 ✓；ai-visual 行无产物文件且无人工确认；
- 任一**强制** EDGE-n / PF-n 未 `- [x]`（允许 `- [x] N/A: 理由`）；
- 任一项标 `需人辅助` 但无 `人工确认`；
- 残留 stub/TODO；desktop 栈源码含 `window.prompt/alert/confirm`。

## tasks.md 书写约定（便于抽取）

- 验收判据用反引号写**完整可执行命令**：`` `cd apps/foo && npm test` ``
- 每故事一行：`- [ ] Txx **独立验收 US1**：…`（中英文冒号均可）
- spec 保留 `### Edge Cases` 段（每条一个 `-` bullet），sync 会逐条变成 EDGE-n

## 与「零 bug」

对齐+完整清单解决**漏项**与**静默跳过**；AI 自测覆盖绝大多数；视觉/外部依赖项靠人辅助闭环。
要更高保障：把 E2E（Playwright / tauri-driver）写进 `verify.yml`，让更多 `ai-visual` 升级为 `ai-auto`。
