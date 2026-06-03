# Spec-Driven 产品工作流

可克隆、可复用的 **Spec Kit 编排 + 可执行门 + Skill 注册表** 工作流模板。

- **设计**：[`ARCHITECTURE.html`](ARCHITECTURE.html)
- **怎么用**：[`USAGE.html`](USAGE.html)（浏览器打开）
- **最高约束**：[`.specify/memory/constitution.md`](.specify/memory/constitution.md)

## 在新电脑上使用

### 1. 克隆并打开

```bash
git clone <你的仓库 URL> workflow
cd workflow
```

用 **Cursor** 打开该目录为工作区。`.cursor/rules/` 会自动加载编排规则。

### 2. 依赖（门脚本）

| 工具 | 用途 |
|------|------|
| `bash` | 所有 `gate-*.sh` |
| `ruby` + `yaml` gem | `activate-dimensions.sh`、registry 解析 |
| `git` | 特性分支、deliver（可选） |

### 3. Web 验证（可选）

做 **web 形态** 的 verify 时，需安装 [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) CLI（`chrome-devtools` 命令）。Skill 已内置在 `.cursor/skills/chrome-devtools-cli/`。

### 4. 跑一条特性

在仓库根目录对 Cursor 说自然语言需求，或依次：

```
/speckit-specify
/speckit-clarify
（技术栈闸门 → 写 specs/<feature>/stack.yml）
/speckit-plan
/speckit-analyze
/speckit-tasks
/speckit-implement
（verify → speckit-verify）
```

特性产物默认在 **`specs/`**（已在 `.gitignore`，不提交具体产品代码）。

### 5. 在本机产品项目里用

两种方式：

- **A. 工作流即仓库**：直接在本仓 `specs/` 下做特性（适合模板/狗食）。
- **B. 复制到新项目**：把 `.cursor/`、`.specify/`、`ARCHITECTURE.html`、`USAGE.html` 拷到产品仓库根，或把本仓作为 submodule。

## Skill 是否都要放进仓库？

**已内置**（`.cursor/skills/`，`registry.yaml` 用相对路径）：

| 类别 | 示例 |
|------|------|
| 编排 | `speckit-*`、`workflow-retro`、`handoff` |
| 通用增强 | `first-principles`、`brainstorming`、`test-driven-development`、`diagnose`、`chrome-devtools-cli` … |
| 领域 | `api-and-interface-design`、`data-modeling`、`security-and-hardening` … |
| 可选 GCP | `gemini-api`、`cloud-run-basics`（仅 `stack.yml` 命中条件时激活） |

**不必**再把 `~/.cursor/skills/first-principles` 单独装一遍——已 vendored 进仓。

新增你自己的 skill：放到 `.cursor/skills/<name>/SKILL.md`，在 `.cursor/registry.yaml` 登记 `path: .cursor/skills/<name>/SKILL.md`，跑：

```bash
.specify/scripts/bash/gate-skill-freshness.sh --max-age-days 365
```

## 门回归（改门后）

```bash
.specify/tests/run-gate-tests.sh
```

## 许可说明

部分 skill 来自上游（见各 skill 的 `origin` / [`.cursor/quarantine/SOURCES.md`](.cursor/quarantine/SOURCES.md)）。 vendored 副本仅供本工作流离线使用，遵循各自上游许可。
