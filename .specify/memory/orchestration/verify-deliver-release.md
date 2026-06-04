# verify / deliver / release

## verify 阶段（implement 之后必做）

「完成」= 被验证过真的能跑，**不接受子 agent 自我汇报**。DoD 见 `.specify/memory/verify-profiles.md`。

**测试主导权**：AI 主导测试，人只审报告。需人辅助项标 `需人辅助` + 步骤，人确认后回填 `人工确认`。

**顺序（硬约束）**：
1. `tasks` 结束后 `sync-verify.sh`
2. 实现代码（WebView/Tauri **禁止** `window.prompt/alert/confirm`）
3. AI 按 coverage **逐条实测**，写 `verify.md`
4. `gate-verify.sh`

详见 `.specify/memory/verify-sync.md` 与 `gates.md` 中 gate-verify 检查项。

## deliver / release 两环节

仅 `stack.yml.release.enabled` 时启用，不替代 verify。

| 环节 | 触发 | 粒度 | 门 |
|------|------|------|-----|
| **deliver** | verify 通过后可跟 MR | per-feature | `gate-deliver.sh` |
| **release** | **仅用户显式要求上线** | 聚合多 feature | `gate-release.sh` |

范式见 `.specify/memory/release-profiles.md`；执行细则见 `speckit-release` skill。

**红线**：不接受口头声称；上线仅用户触发；外部工具不替代本环节。
