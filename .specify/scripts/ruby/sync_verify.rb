#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate verify-coverage.yml from spec.md + tasks.md + stack.yml,
# merge required commands into verify.yml, scaffold verify.md acceptance table.
#
# Usage: sync_verify.rb FEATURE_DIR REPO_ROOT [--check|--dry-run]

require "yaml"
require "fileutils"
require "time"
require "set"

FEATURE_DIR = File.expand_path(ARGV[0] || ENV.fetch("FEATURE_DIR"))
REPO_ROOT = File.expand_path(ARGV[1] || ENV.fetch("REPO_ROOT", FEATURE_DIR))
MODE = (ARGV[2] || ENV["SYNC_VERIFY_MODE"] || "sync").to_s # sync | check | dry-run

SPEC = File.join(FEATURE_DIR, "spec.md")
TASKS = File.join(FEATURE_DIR, "tasks.md")
STACK = File.join(FEATURE_DIR, "stack.yml")
PLAN = File.join(FEATURE_DIR, "plan.md")
VERIFY_YML = File.join(FEATURE_DIR, "verify.yml")
VERIFY_MD = File.join(FEATURE_DIR, "verify.md")
COVERAGE_YML = File.join(FEATURE_DIR, "verify-coverage.yml")

abort "sync_verify: missing FEATURE_DIR" unless File.directory?(FEATURE_DIR)
abort "sync_verify: missing spec.md" unless File.file?(SPEC)
abort "sync_verify: missing tasks.md" unless File.file?(TASKS)

def read(path)
  File.read(path, encoding: "UTF-8")
rescue StandardError
  ""
end

def load_yaml(path)
  return {} unless File.file?(path)

  YAML.safe_load(File.read(path, encoding: "UTF-8"), permitted_classes: [], aliases: true) || {}
rescue StandardError
  {}
end

def normalize_run(cmd)
  cmd.to_s.strip.gsub(/\s+/, " ")
end

def slug(s)
  s.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
end

# 各形态「专项 DoD」——AI 应尽量自动验证；owner 标 ai-auto / ai-visual（AI 截图判断，拿不准叫人）。
PROFILE_CHECKS = {
  "web" => [
    { "t" => "构建/单测命令全绿", "owner" => "ai-auto" },
    { "t" => "chrome-devtools-cli 打开页面：console 零 error", "owner" => "ai-auto" },
    { "t" => "关键路由/页面可达，无 404/白屏", "owner" => "ai-auto" },
    { "t" => "空 / 加载 / 错误 三态可见（截图）", "owner" => "ai-visual" },
    { "t" => "UX 红线符合 plan（弹窗不内联、关键流程在位）", "owner" => "ai-visual" }
  ],
  "desktop" => [
    { "t" => "构建/单测命令全绿", "owner" => "ai-auto" },
    { "t" => "真启动 GUI（dev 或打包产物），窗口出现无白屏", "owner" => "ai-visual" },
    { "t" => "源码无 window.prompt/alert/confirm（gate 已扫）", "owner" => "ai-auto" },
    { "t" => "控制台/终端无未处理 panic 或 error", "owner" => "ai-auto" },
    { "t" => "空 / 有数据 / 错误提示 三态可见（截图）", "owner" => "ai-visual" }
  ],
  "cli" => [
    { "t" => "`--help` 正常输出用法", "owner" => "ai-auto" },
    { "t" => "正常输入产出预期 stdout，退出码 0", "owner" => "ai-auto" },
    { "t" => "非法输入：清晰报错且退出码 ≠ 0", "owner" => "ai-auto" },
    { "t" => "边界输入（空/超长/stdin/缺文件）不崩溃", "owner" => "ai-auto" }
  ],
  "service" => [
    { "t" => "启动服务并通过健康检查（如 /healthz 200）", "owner" => "ai-auto" },
    { "t" => "关键端点正常请求返回预期 status/body", "owner" => "ai-auto" },
    { "t" => "错误语义：4xx/5xx 在该返回时返回，契约一致", "owner" => "ai-auto" },
    { "t" => "未授权端点正确拒绝", "owner" => "ai-auto" }
  ],
  "library" => [
    { "t" => "测试套件全绿（单元 + 关键集成）", "owner" => "ai-auto" },
    { "t" => "公共 API 冒烟：按 README/示例调用主路径成功", "owner" => "ai-auto" },
    { "t" => "示例 / quickstart 代码可跑", "owner" => "ai-auto" },
    { "t" => "公共接口签名与文档/契约一致（无意外 breaking）", "owner" => "ai-auto" }
  ],
  "pipeline" => [
    { "t" => "样本输入端到端跑通，产出非空", "owner" => "ai-auto" },
    { "t" => "输出 schema / 行数 / 关键字段校验通过", "owner" => "ai-auto" },
    { "t" => "幂等 / 可重跑：重复运行无脏数据", "owner" => "ai-auto" },
    { "t" => "失败可观测：异常有日志、可定位失败步骤", "owner" => "ai-auto" }
  ],
  "unknown" => [
    { "t" => "通用底线全过（真启动/零报错/验收/无残留/测试真跑）", "owner" => "ai-auto" },
    { "t" => "建议回 plan 在 stack.yml 补 form:", "owner" => "ai-auto" }
  ]
}.freeze

# --- Parse spec: user stories + scenario counts ---
def runnable_command?(cmd)
  return false if cmd.to_s.strip.empty?
  return false if cmd =~ %r{\A/} # slash commands like /speckit-analyze
  return false if cmd =~ /\Averify\z/i
  return false if cmd =~ /\A(tauri dev|tauri build)\z/ # need npm run prefix + cd

  cmd =~ /\A(cd |npm |cargo |pnpm |yarn |make |pytest |go test|dotnet )/
end

def parse_user_stories(spec_text)
  stories = []
  spec_text.scan(/^### User Story (\d+) - (.+?)\s*$/m) do |num, title|
    title = title.sub(/\s*（Priority:.*?\）\s*$/, "").sub(/\s*\(Priority:.*?\)\s*$/, "").strip
    stories << { id: "US#{num}", title: title, kind: "user_story" }
  end
  stories.each do |st|
    block = spec_text[/^### User Story #{st[:id].sub("US", "")} - .+?\n(.*?)(?=^### |\z)/m] || ""
    st[:scenario_count] = block.scan(/^\d+\.\s+\*\*Given\*\*/m).size
    st[:type] = "gui" # overridden later from stack/form
  end
  stories
end

# --- Parse tasks: shell commands + 独立验收 ---
def parse_tasks(tasks_text)
  commands = []
  seen = {}

  add_cmd = lambda do |run, source|
    run = normalize_run(run)
    return if run.empty? || run.include?("create tauri-app")

    key = run
    unless seen[key]
      seen[key] = true
      name = slug(run.split.first(3).join("-"))
      commands << { "id" => "cmd-#{commands.size + 1}", "name" => name, "run" => run, "sources" => [source] }
    else
      existing = commands.find { |c| c["run"] == run }
      existing["sources"] << source unless existing["sources"].include?(source)
    end
  end

  # Backtick commands in tasks
  tasks_text.scan(/`([^`]+)`/) do |m|
    cmd = m[0]
    next unless runnable_command?(cmd)

    add_cmd.call(cmd, "tasks.md")
  end

  # 验收判据 section bullets
  if (sec = tasks_text[/## 验收判据.*?\n(.*?)(?:\n## |\z)/m])
    sec.scan(/^-\s+(.+)$/m).each do |line|
      line[0].scan(/`([^`]+)`/).each { |m| add_cmd.call(m[0], "tasks.md:验收判据") }
    end
  end

  acceptance_tasks = []
  tasks_text.scan(/^- \[.\] (T\d+).*\*\*独立验收 (US\d+)\*\*[:：]\s*([^\n]+)/) do |tid, us, desc|
    acceptance_tasks << { task: tid, id: us, desc: desc.strip }
  end

  { commands: commands, acceptance_tasks: acceptance_tasks }
end

# --- Parse spec: Edge Cases ---
def parse_edge_cases(spec_text)
  block = spec_text[/^###?\s*Edge Cases\s*\n(.*?)(?=^### |^##\s|\z)/m]
  return [] unless block

  body = block.sub(/^###?\s*Edge Cases\s*\n/, "")
  cases = []
  body.scan(/^[-*]\s+(.+?)\s*$/) do |m|
    text = m[0].gsub(/\s+/, " ").strip
    next if text.empty?

    cases << text
  end
  cases
end

def infer_app_dir(plan_text, tasks_text, _stack)
  dir = nil
  if (m = tasks_text.match(/\*\*Output dir\*\*:\s*`([^`]+)`/))
    dir = m[1].strip
  elsif (m = plan_text.match(%r{`?(apps/[^`\s/]+)`?}))
    dir = m[1].strip
  elsif (m = plan_text.match(%r{apps/[a-z0-9-]+}))
    dir = m[0]
  end
  dir&.sub(%r{/\z}, "")
end

def default_commands(app_dir, form, stack)
  cmds = []
  return cmds unless app_dir

  base = "cd #{app_dir}"
  cmds << { "id" => "cmd-frontend-build", "name" => "frontend-build", "run" => "#{base} && npm run build",
            "sources" => ["sync:stack-default"] }
  cmds << { "id" => "cmd-frontend-test", "name" => "frontend-test", "run" => "#{base} && npm test",
            "sources" => ["sync:stack-default"] }
  if File.directory?(File.join(REPO_ROOT, app_dir, "src-tauri"))
    cmds << { "id" => "cmd-rust-test", "name" => "rust-test",
              "run" => "cd #{app_dir}/src-tauri && cargo test", "sources" => ["sync:stack-default"] }
  end
  if form == "desktop" && stack.is_a?(Hash) && stack.to_yaml.downcase.include?("tauri")
    cmds << {
      "id" => "cmd-tauri-build", "name" => "tauri-build",
      "run" => "#{base} && npm run tauri build",
      "optional" => true, # 慢；VERIFY_FULL=1 或 release 前再跑
      "sources" => ["sync:stack-default", "tasks.md:验收判据"]
    }
  end
  cmds
end

def merge_commands(*lists)
  by_run = {}
  lists.flatten.each do |c|
    run = normalize_run(c["run"])
    next if run.empty?

    if by_run[run]
      by_run[run]["sources"] = (by_run[run]["sources"] + c["sources"]).uniq
      by_run[run]["name"] ||= c["name"]
    else
      by_run[run] = c.merge("run" => run)
    end
  end
  by_run.values
end

def resolve_form(stack, verify)
  verify["form"].to_s.strip.empty? ? stack["form"].to_s : verify["form"].to_s
end

def gui_required?(form, stack)
  return true if %w[web desktop].include?(form)
  return true if stack["ui"] == true

  false
end

def build_coverage
  spec_text = read(SPEC)
  tasks_text = read(TASKS)
  stack = load_yaml(STACK)
  plan_text = read(PLAN)
  verify = load_yaml(VERIFY_YML)

  form = resolve_form(stack, verify)
  form = "unknown" if form.empty?

  app_dir = infer_app_dir(plan_text, tasks_text, stack)
  stories = parse_user_stories(spec_text)
  task_data = parse_tasks(tasks_text)

  stories.each { |s| s["type"] = gui_required?(form, stack) ? "gui" : "manual" }

  # 复杂度分档：trivial → US + PF（EDGE 软提示）；standard/complex → US + EDGE + PF 全硬性。
  complexity = (stack["complexity"] || "standard").to_s.strip
  tier = %w[trivial standard complex].include?(complexity) ? complexity : "standard"
  edge_enforced = tier != "trivial"

  gui = gui_required?(form, stack)
  acceptance = stories.map do |st|
    task_ref = task_data[:acceptance_tasks].find { |t| t[:id] == st[:id] }
    {
      "id" => st[:id],
      "title" => st[:title],
      "type" => st[:type],
      "kind" => "user_story",
      # GUI 的功能验收默认 ai-visual（AI 启动+操作+截图判断；拿不准叫人）；非 GUI 默认 ai-auto。
      "owner" => gui ? "ai-visual" : "ai-auto",
      "enforced" => true,
      "scenario_count" => st[:scenario_count],
      "task_refs" => task_ref ? [task_ref[:task]] : [],
      "independent_test" => task_ref&.dig(:desc)
    }
  end

  edge_list = parse_edge_cases(spec_text)
  edge_cases = edge_list.each_with_index.map do |t, i|
    { "id" => "EDGE-#{i + 1}", "title" => t, "owner" => "ai-auto", "enforced" => edge_enforced }
  end

  profile_src = PROFILE_CHECKS[form] || PROFILE_CHECKS["unknown"]
  profile_checks = profile_src.each_with_index.map do |c, i|
    { "id" => "PF-#{i + 1}", "title" => c["t"], "owner" => c["owner"], "enforced" => true }
  end

  # #2 抽空即报警：spec 明明有相应区块却抽出 0 条 = 格式漂移，宁报错不假绿。
  parse_health = []
  if spec_text =~ /^###\s*User Story/ && stories.empty?
    parse_health << "spec 含 User Story 区块但解析出 0 条（格式漂移？须 `### User Story N - 标题`）"
  end
  if spec_text =~ /^###?\s*Edge Cases/ && edge_list.empty?
    parse_health << "spec 含 Edge Cases 区块但解析出 0 条（须每条以 `- ` 列出）"
  end

  defaults = default_commands(app_dir, form, stack)
  defaults.each { |c| c["run"] = canonicalize_run(c["run"], app_dir) }
  task_data[:commands].each { |c| c["run"] = canonicalize_run(c["run"], app_dir) }
  commands = merge_commands(defaults, task_data[:commands])
  commands.select! { |c| runnable_command?(c["run"]) }
  # 已有 src-tauri 的 cargo test 时，去掉 app 根目录的重复 cargo test
  rust_runs = commands.select { |c| c["run"] =~ %r{src-tauri && cargo test} }
  if rust_runs.any?
    commands.reject! { |c| c["run"] =~ /\Acd #{Regexp.escape(app_dir.to_s)} && cargo test\z/ }
  end

  scan_paths = []
  if app_dir
    scan_paths << "#{app_dir}/src" if File.directory?(File.join(REPO_ROOT, app_dir, "src"))
    scan_paths << "#{app_dir}/src-tauri/src" if File.directory?(File.join(REPO_ROOT, app_dir, "src-tauri", "src"))
  end
  existing = verify["scan_paths"]
  scan_paths = (scan_paths + Array(existing)).uniq if existing

  gui_checklist = []
  if gui_required?(form, stack)
    gui_checklist = [
      { "id" => "gui-start", "title" => "真启动 GUI（dev 或打包产物），无白屏" },
      { "id" => "gui-dialog", "title" => "新建/删除使用应用内 Dialog（非 window.prompt）" },
      { "id" => "gui-persist", "title" => "重启后数据仍在" }
    ]
  end

  {
    "generated_at" => Time.now.utc.iso8601,
    "generator" => "sync-verify.rb",
    "policy" => "AI 主导测试 · 人审报告；能自动则自动；需人则显式叫人辅助后再完成（见 verify-sync.md）",
    "sources" => { "spec" => "spec.md", "tasks" => "tasks.md", "stack" => File.file?(STACK) ? "stack.yml" : nil }.compact,
    "form" => form,
    "tier" => tier,
    "app_dir" => app_dir,
    "parse_health" => parse_health,
    "commands_required" => commands,
    "acceptance_required" => acceptance,
    "edge_cases" => edge_cases,
    "profile_checks" => profile_checks,
    "gui_checklist" => gui_checklist,
    "scan_paths_suggested" => scan_paths
  }
end

def verify_yml_commands(verify)
  Array(verify["commands"]).map do |c|
    normalize_run(c["run"]) if c.is_a?(Hash)
  end.compact
end

# 一行是否含「未结案」占位（待跑 / 待人辅助但未确认）。
def pending_placeholder?(line)
  line =~ /待[[:space:]]*(GUI|跑|测|验证|补)/
end

def human_confirmed?(line)
  line =~ /人工确认[:：]\s*\S/ || line =~ /已确认|confirmed/
end

# 「需人辅助」项必须记录人工确认才算结案。
def needs_human_unconfirmed?(line)
  (line =~ /需人|待人工|人工辅助|human-assist/) && !human_confirmed?(line)
end

def na_exempt?(line)
  line =~ /N\/A[:：]\s*\S/
end

# #1 ai-visual 防自述：证据须引用真实存在的产物文件（截图/日志/报告），否则须转需人辅助+人工确认。
def artifact_exists?(line)
  line.scan(%r{([\w./\-]+\.(?:png|jpe?g|webp|gif|svg|log|txt|html|json|webm|mp4))}i).any? do |m|
    rel = m[0].sub(%r{\A\./}, "")
    [File.join(FEATURE_DIR, rel), File.join(REPO_ROOT, rel), rel].any? { |c| File.file?(c) }
  end
end

def check_alignment(coverage, verify, verify_md_text)
  errors = []

  # #2 解析健康：抽空即报警（先于一切，防假绿）。
  Array(coverage["parse_health"]).each { |w| errors << "覆盖解析异常: #{w}" }

  yml_runs = verify_yml_commands(verify).to_set
  app_dir = coverage["app_dir"]
  coverage["commands_required"].each do |req|
    run = canonicalize_run(req["run"], app_dir)
    unless yml_runs.include?(run)
      errors << "verify.yml 缺少命令: [#{req['name']}] #{run} (来源: #{req['sources'].join(', ')})"
    end
  end

  lines = verify_md_text.lines

  # 1) 功能验收（User Story）——每条须 ✓；ai-visual 须有产物或转需人确认。
  coverage["acceptance_required"].each do |acc|
    id = acc["id"]
    pat = /\|\s*#{Regexp.escape(id)}(\s|[|｜])/
    line = lines.find { |l| l =~ pat }
    unless line
      errors << "verify.md 缺少验收行: #{id} (#{acc['title']})"
      next
    end
    if pending_placeholder?(line)
      errors << "verify.md #{id} 仍为待跑占位"
    elsif needs_human_unconfirmed?(line)
      errors << "verify.md #{id} 标了需人辅助但缺『人工确认』"
    elsif line !~ /\|\s*✓/
      errors << "verify.md #{id} 未标记 ✓（AI 实跑/人辅助确认后填写）"
    elsif acc["owner"] == "ai-visual" && !artifact_exists?(line) && !human_confirmed?(line)
      errors << "verify.md #{id} 为视觉项：须引用真实产物文件(截图/E2E 报告)或转『需人辅助+人工确认』，禁止纯文字自述"
    end
  end

  # 2) 边界场景（spec Edge Cases）——standard/complex 硬性；trivial 软提示。
  coverage["edge_cases"].each do |ec|
    next unless ec["enforced"]

    errors.concat(check_checkbox_item(lines, ec, "边界场景"))
  end

  # 3) 形态专项 DoD——每条须结案；ai-visual 须有产物或转需人确认。
  coverage["profile_checks"].each do |pf|
    next unless pf["enforced"]

    errors.concat(check_checkbox_item(lines, pf, "形态专项"))
  end

  errors
end

def check_checkbox_item(lines, item, label)
  errs = []
  id = item["id"]
  line = lines.find { |l| l.include?("(#{id})") }
  unless line
    return ["verify.md 缺少#{label}行: (#{id}) #{item['title']}"]
  end
  if pending_placeholder?(line)
    errs << "verify.md (#{id}) 仍为待跑占位"
  elsif needs_human_unconfirmed?(line)
    errs << "verify.md (#{id}) 标了需人辅助但缺『人工确认』"
  elsif line !~ /^\s*-\s*\[[xX]\]/
    errs << "verify.md (#{id}) 未结案（须 - [x]，或写明 N/A: 理由）"
  elsif item["owner"] == "ai-visual" && !na_exempt?(line) && !artifact_exists?(line) && !human_confirmed?(line)
    errs << "verify.md (#{id}) 为视觉项：须引用真实产物文件(截图/E2E 报告)或转『需人辅助+人工确认』，禁止纯文字自述"
  end
  errs
end

def canonicalize_run(run, app_dir)
  run = normalize_run(run)
  return run if run.start_with?("cd ")

  if app_dir && run == "cargo test" && File.directory?(File.join(REPO_ROOT, app_dir, "src-tauri"))
    return "cd #{app_dir}/src-tauri && cargo test"
  end
  if app_dir && run =~ /\A(npm|cargo)/
    return "cd #{app_dir} && #{run}"
  end
  run
end

def merge_verify_yml(coverage, verify)
  verify = verify.dup
  verify["form"] ||= coverage["form"]
  verify["_sync"] = {
    "generated_from" => "verify-coverage.yml",
    "generated_at" => coverage["generated_at"],
    "note" => "commands 由 sync-verify 从 spec/tasks 生成；acceptance 见 verify-coverage.yml"
  }

  app_dir = coverage["app_dir"]
  by_run = {}

  # 保留人工追加、非 auto_sync 的命令
  Array(verify["commands"]).each do |c|
    next unless c.is_a?(Hash) && c["run"]
    next if c["auto_sync"] == true

    run = canonicalize_run(c["run"], app_dir)
    by_run[run] = c.merge("run" => run)
  end

  coverage["commands_required"].each do |req|
    run = canonicalize_run(req["run"], app_dir)
    entry = {
      "id" => req["id"],
      "name" => req["name"],
      "run" => run,
      "auto_sync" => true,
      "sources" => req["sources"]
    }
    entry["optional"] = true if req["optional"]
    by_run[run] = entry
  end

  verify["commands"] = by_run.values
  if verify["scan_paths"].nil? || Array(verify["scan_paths"]).empty?
    verify["scan_paths"] = coverage["scan_paths_suggested"] if coverage["scan_paths_suggested"].any?
  end
  verify["acceptance"] = coverage["acceptance_required"].map do |a|
    { "id" => a["id"], "title" => a["title"], "type" => a["type"] }
  end
  verify
end

OWNER_LABEL = {
  "ai-auto" => "AI 自动",
  "ai-visual" => "AI 截图判断",
  "needs-human" => "需人辅助"
}.freeze

def acceptance_section(coverage)
  rows = coverage["acceptance_required"].map do |a|
    hint = a["independent_test"] || "见 spec Acceptance Scenarios"
    "| #{a["id"]} #{a["title"]} | | #{OWNER_LABEL[a["owner"]] || a["owner"]} | #{hint} |"
  end.join("\n")
  <<~SEC

    ## 验收场景（spec User Story · 须实跑）

    > 结果列：✓ 通过 / ✗ 失败 / 需人辅助(写明原因+人给的步骤+「人工确认: …」)。不得留空或「待跑」。
    > `AI 截图判断` 行的证据须含**真实产物文件路径**（如 `verify-artifacts/us1.png`）或「人工确认: …」。

    | 场景 | 结果 | 执行 | 证据 |
    |------|------|------|------|
    #{rows}
  SEC
end

def edge_section(coverage)
  return "" if coverage["edge_cases"].empty?

  rows = coverage["edge_cases"].map do |e|
    "- [ ] (#{e["id"]}) #{e["title"]} — 证据: "
  end.join("\n")
  <<~SEC

    ## 边界与异常（spec Edge Cases · 逐条结案）

    > 每条须 `- [x]`（含证据），无关则写 `- [x] N/A: 理由`。

    #{rows}
  SEC
end

def profile_section(coverage)
  return "" if coverage["profile_checks"].empty?

  rows = coverage["profile_checks"].map do |p|
    "- [ ] (#{p["id"]}) [#{OWNER_LABEL[p["owner"]] || p["owner"]}] #{p["title"]} — 证据: "
  end.join("\n")
  <<~SEC

    ## 形态专项 DoD（form: #{coverage["form"]} · 逐条结案）

    > AI 先自动验证；`AI 截图判断` 项拿不准时叫人辅助并记『人工确认: …』。

    #{rows}
  SEC
end

def report_header(coverage)
  <<~HDR
    # Verify 测试报告: [FEATURE]

    **Date**: #{Time.now.strftime("%Y-%m-%d")} | **Form**: #{coverage["form"]} | **Tier**: #{coverage["tier"]} | **Coverage**: verify-coverage.yml

    > 测试策略：**AI 主导测试，人审本报告**。能自动的 AI 已自动跑；标「需人辅助」的项，AI 会请你协助后补「人工确认」再结案。
    > 视觉项（ai-visual）证据**须引用真实产物文件**（截图/E2E 报告，建议放 `verify-artifacts/`）或转「需人辅助+人工确认」，**禁止纯文字自述**。
    > 所有验收/专项项必须结案（✓ 或 - [x]），否则 `gate-verify.sh` 阻断。

    ## 机械门（gate-verify.sh）

    | 命令 | 退出码 |
    |------|--------|
  HDR
end

def ensure_section(text, header_regex, section_body)
  return text if text =~ header_regex

  text.rstrip + "\n\n" + section_body.lstrip
end

def scaffold_verify_md(coverage, existing)
  if existing.strip.empty?
    cmd_rows = coverage["commands_required"].map { |c| "| `#{c["name"]}` | （跑 gate 后填） |" }.join("\n")
    return report_header(coverage) + cmd_rows + "\n\n`gate-verify.sh`: **待跑**\n" +
           acceptance_section(coverage) + edge_section(coverage) + profile_section(coverage)
  end

  # 已有 verify.md：补缺失的 US 行 + 缺失的 边界/专项 整段（不动已填内容）。
  updated = existing.dup

  coverage["acceptance_required"].each do |a|
    pat = /\|\s*#{Regexp.escape(a["id"])}(\s|[|｜])/
    next if updated =~ pat

    row = "| #{a["id"]} #{a["title"]} | | #{OWNER_LABEL[a["owner"]]} | #{a["independent_test"] || "见 spec"} |\n"
    if updated =~ /^##\s*验收场景/
      updated.sub!(/(^##\s*验收场景[^\n]*\n(?:>.*\n|\s*\n)*?\|[^\n]+\n\|[-\s|]+\n(?:\|[^\n]+\n)*)/m) { |m| m + row }
    else
      updated = updated.rstrip + "\n" + acceptance_section(coverage) + row
    end
  end

  updated = ensure_section(updated, /^##\s*边界与异常/, edge_section(coverage)) unless coverage["edge_cases"].empty?
  updated = ensure_section(updated, /^##\s*形态专项/, profile_section(coverage)) unless coverage["profile_checks"].empty?
  updated
end

# --- Main ---
coverage = build_coverage
verify = load_yaml(VERIFY_YML)
verify_md = read(VERIFY_MD)

errors = check_alignment(coverage, verify, verify_md)

case MODE
when "check"
  if errors.empty?
    puts "SYNC-VERIFY: ✓ 对齐 (tier=#{coverage["tier"]}, US=#{coverage["acceptance_required"].size} EDGE=#{coverage["edge_cases"].size} PF=#{coverage["profile_checks"].size})"
    exit 0
  else
    puts "SYNC-VERIFY: FAIL — 未对齐/未结案项:"
    errors.each { |e| puts "  - #{e}" }
    puts "  → 修复 verify.md/spec/tasks 或重跑: .specify/scripts/bash/sync-verify.sh"
    exit 1
  end
when "dry-run"
  puts YAML.dump(coverage)
  puts "--- check errors ---"
  errors.each { |e| puts e }
  exit(errors.empty? ? 0 : 1)
else # sync
  cov_header = "# AUTO-GENERATED by sync-verify.sh — 勿手改；改 spec/tasks 后重新 sync\n"
  unless MODE == "dry-run"
    File.write(COVERAGE_YML, cov_header + YAML.dump(coverage))
    puts "SYNC-VERIFY: wrote #{COVERAGE_YML}"
  end

  merged = merge_verify_yml(coverage, verify)
  File.write(VERIFY_YML, YAML.dump(merged))
  puts "SYNC-VERIFY: merged #{VERIFY_YML} (#{merged['commands'].size} commands)"

  new_md = scaffold_verify_md(coverage, verify_md)
  if verify_md.strip.empty? || (new_md != verify_md && verify_md !~ /\| US\d+/)
    File.write(VERIFY_MD, new_md) unless MODE == "dry-run"
    puts "SYNC-VERIFY: scaffolded #{VERIFY_MD}"
  elsif new_md != verify_md
    # Only add missing rows — write if we added US rows
    File.write(VERIFY_MD, new_md)
    puts "SYNC-VERIFY: updated #{VERIFY_MD} (added missing acceptance rows)"
  end

  errors = check_alignment(coverage, merged, read(VERIFY_MD))
  if errors.empty?
    puts "SYNC-VERIFY: ✓ 对齐完成"
    exit 0
  else
    puts "SYNC-VERIFY: 已同步；仍需人工/AI 完成:"
    errors.each { |e| puts "  - #{e}" }
    exit 0 # sync succeeds; gate-verify will block until verify.md filled
  end
end
