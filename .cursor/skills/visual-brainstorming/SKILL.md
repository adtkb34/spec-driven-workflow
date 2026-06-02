---
name: visual-brainstorming
description: >-
  Browser-based visual companion for UI/UX design questions—shows wireframes, layout
  options, and mockups in the browser so the user picks by seeing rather than reading.
  Use during specify/clarify when the question is visual (layout, navigation, visual
  style, side-by-side comparison) and the answer is a visual preference, not words.
  Triggers: UI/界面/交互稿/线框/视觉风格/布局选型/UI mockup。
---

# Visual Brainstorming（UI/UX 可视化共创）

支撑 `ux_design` 维度（registry，`bind_phase: [specify, clarify]`）。用本地预览 server 把
布局/导航/视觉风格等**视觉问题**渲染成可点击 mockup，让用户「看着选」，结论回流到 spec。

> origin: obra/superpowers · brainstorming 的 visual companion（commit `6fd4507`），
> 经隔离区审查（脚本仅本地 `http` server，无外联）后提级。

## Quick start

1. **判定（逐题判，不整段判）**：这道题用户「看图」比「读字」更好懂吗？
   - 是（布局/导航/视觉风格/并排比较/设计打磨）→ 用浏览器（本 skill）。
   - 否（需求范围/概念 A/B/C/取舍清单/API 与数据建模等技术决策）→ 留在终端，交回 `brainstorming` / `first-principles`。
   - 关于 UI 的问题不等于视觉问题：「要什么样的向导？」是概念题（终端）；「这几个向导布局哪个对？」是视觉题（浏览器）。
2. **启动 server**：`scripts/start-server.sh --project-dir <项目根>`，记下返回 JSON 里的 `url` / `screen_dir` / `state_dir`，让用户打开 URL。
3. **循环**：向 `screen_dir` 写新的 HTML 片段（语义文件名，不复用）→ 文字简述屏幕内容并结束本轮 → 下轮读 `state_dir/events`（点击记录）合并用户文字反馈 → 迭代或推进。
4. **收尾**：把确认的视觉结论**写回 spec**（不要只留在 mockup 里）；不需要浏览器时推一张 waiting 屏清场；结束 `scripts/stop-server.sh <session_dir>`。

详细机制、可用 CSS 类、事件格式、跨平台启动方式见 [visual-companion.md](visual-companion.md)。

## 与本工作流的衔接

- **维度**：`ux_design`，仅在「有 UI/界面/交互设计需求」命中时由 specify/clarify 激活；纯 CLI/后端项目不启用。
- **分工**：`brainstorming` 管概念发散、`first-principles` 管砍需求/取舍、本 skill 只管**视觉选型**；三者同阶段并行，不互相覆盖。
- **不替代闸门**：可视化结论仍要进 spec 并经后续 clarify 消除模糊点；不替代技术栈闸门与 verify。

## 红线

- mockup 是**讨论媒介不是交付物**：聚焦布局与结构，别陷入像素级打磨。
- 每屏 2–4 个选项；每屏写清在问什么（「哪个更专业？」而非「选一个」）。
- 视觉结论必须回写 spec，否则视为未捕获。
- server 仅本地运行；提醒用户把 `.superpowers/` 加入 `.gitignore`。
