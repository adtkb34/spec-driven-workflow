#!/usr/bin/env bash
# Executable gate: spec business-dimension coverage (not just placeholder markers).
# Blocks when spec looks "complete" but Input Q&A / spec-coverage.yml show unconfirmed gaps.
#
# Usage: ./gate-spec-coverage.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-SPEC-COVERAGE: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

COVERAGE_FILE="$FEATURE_DIR/spec-coverage.yml"
STACK_FILE="$FEATURE_DIR/stack.yml"

if [[ ! -f "$FEATURE_SPEC" ]]; then
    echo "GATE-SPEC-COVERAGE: ERROR spec.md not found at $FEATURE_SPEC" >&2
    exit 2
fi

command -v ruby >/dev/null 2>&1 || { echo "GATE-SPEC-COVERAGE: ERROR requires ruby (yaml)" >&2; exit 2; }

export FEATURE_SPEC COVERAGE_FILE STACK_FILE
ruby <<'RUBY'
require 'yaml'

spec_path = ENV['FEATURE_SPEC']
cov_path  = ENV['COVERAGE_FILE']
stack_path = ENV['STACK_FILE']
spec = File.read(spec_path, encoding: 'UTF-8')
failures = []

def fail!(failures, msg)
  failures << msg
end

# --- A: spec-coverage.yml exists with ping_completed_at ---
unless File.exist?(cov_path)
  fail!(failures, "缺少 spec-coverage.yml（Post-Draft Ping 未落盘）")
else
  cov = YAML.load_file(cov_path) || {}
  ping_at = cov['ping_completed_at'].to_s.strip
  if ping_at.empty?
    fail!(failures, "spec-coverage.yml 缺少 ping_completed_at")
  end

  complexity = cov['complexity'].to_s.strip
  if File.exist?(stack_path)
    stack = YAML.load_file(stack_path) || {}
    sc = stack['complexity'].to_s.strip
    complexity = sc unless sc.empty?
  end
  complexity = 'standard' if complexity.empty?

  dims = cov['dimensions'] || {}
  bg = (dims['background'] || {})['status'].to_s.strip
  fail!(failures, "dimensions.background.status 须为 covered（当前: #{bg.empty? ? 'missing' : bg}）") unless bg == 'covered'

  as_is = dims['as_is'] || {}
  baseline = dims['baseline'] || {}
  ai_st = as_is['status'].to_s.strip
  bl_st = baseline['status'].to_s.strip

  ok_dim = ->(s) { %w[covered waived partial].include?(s) }

  if complexity == 'trivial'
    fail!(failures, "trivial: as_is 须 covered|waived|partial（当前: #{ai_st.empty? ? 'missing' : ai_st}）") unless ok_dim.call(ai_st)
    if ai_st == 'waived' && as_is['note'].to_s.strip.empty?
      fail!(failures, "as_is waived 须填写 note")
    end
  else
    fail!(failures, "standard/complex: as_is 须 covered|waived|partial（当前: #{ai_st.empty? ? 'missing' : ai_st}）") unless ok_dim.call(ai_st)
    fail!(failures, "standard/complex: baseline 须 covered|waived|partial（当前: #{bl_st.empty? ? 'missing' : bl_st}）") unless ok_dim.call(bl_st)
  end

  if as_is['status'].to_s == 'waived' && as_is['note'].to_s.strip.empty?
    fail!(failures, "as_is waived 须填写 note")
  end
  if baseline['status'].to_s == 'waived' && baseline['note'].to_s.strip.empty?
    fail!(failures, "baseline waived 须填写 note")
  end

  # --- G: input_qa_count vs spec ---
  counts = cov['input_qa_count'] || {}
  spec_counts = { '2' => 0, '3' => 0, '4' => 0, '5' => 0 }
  current = nil
  spec.each_line do |line|
    if line =~ /^###\s*②/
      current = '2'
    elsif line =~ /^###\s*③/
      current = '3'
    elsif line =~ /^###\s*④/
      current = '4'
    elsif line =~ /^###\s*⑤/
      current = '5'
    elsif current && line =~ /^-\s+\*\*Q:\*\*/
      spec_counts[current] += 1 unless line.include?('_(none yet)_')
    end
  end
  counts.each do |k, v|
    yaml_n = v.to_i
    spec_n = spec_counts[k.to_s] || 0
    if yaml_n != spec_n
      fail!(failures, "input_qa_count[#{k}]=#{yaml_n} 与 spec Input Q&A 计数 #{spec_n} 不一致")
    end
  end

  if complexity == 'trivial'
    total_qa = counts.values.map { |x| x.to_i }.sum
    fail!(failures, "trivial: input_qa_count 合计须 >= 1") if total_qa < 1
  end
end

# --- D: Input Q&A with real Q/A ---
unless spec.include?('## Input Q&A')
  fail!(failures, "spec 缺少 ## Input Q&A (②③④⑤) 节")
else
  qa_lines = spec.lines.select { |l| l =~ /^-\s+\*\*Q:\*\*/ && !l.include?('_(none yet)_') }
  has_a = spec.include?('**A:**')
  if qa_lines.empty? || !has_a
    fail!(failures, "Input Q&A 须至少一条 - **Q:** … **A:** …（非 _(none yet)_）")
  end
end

# --- E: template placeholder scan ---
patterns = [
  ['[Background, goals', 'Background & Goals 仍为模板占位'],
  ['[Brief Title]', 'User Story 仍为 [Brief Title] 模板'],
  ['[specific capability', 'Functional Requirements 仍为模板占位'],
  ['[Measurable metric', 'Success Criteria 仍为模板占位'],
  ['[User satisfaction metric', 'Success Criteria 仍为模板占位'],
  ['[Business metric', 'Success Criteria 仍为模板占位'],
  ['[boundary condition]', 'Edge Cases 仍为模板占位'],
  ['[error scenario]', 'Edge Cases 仍为模板占位'],
  ['[Entity 1]', 'Key Entities 仍为模板占位'],
  ['[Assumption about', 'Assumptions 仍为模板占位'],
  ['[Dependency on existing', 'Assumptions 仍为模板占位'],
  ['[FEATURE NAME]', '标题仍为模板占位'],
  ['[###-feature-name]', 'Feature Branch 仍为模板占位'],
  ['[DATE]', 'Created 日期仍为模板占位'],
  ['[Describe this user journey', 'User Story 正文仍为模板占位']
]
patterns.each do |pat, msg|
  fail!(failures, msg) if spec.include?(pat)
end

# --- F: Assumptions tagging (standard/complex) ---
complexity = 'standard'
if File.exist?(cov_path)
  complexity = (YAML.load_file(cov_path) || {})['complexity'].to_s.strip
end
if File.exist?(stack_path)
  sc = (YAML.load_file(stack_path) || {})['complexity'].to_s.strip
  complexity = sc unless sc.empty?
end
complexity = 'standard' if complexity.empty?

if complexity != 'trivial' && spec =~ /^## Assumptions\b/m
  in_assumptions = false
  spec.each_line do |line|
    if line =~ /^## Assumptions\b/
      in_assumptions = true
      next
    end
    if in_assumptions && line =~ /^## /
      break
    end
    next unless in_assumptions
    next unless line =~ /^-\s+/
    text = line.sub(/^-\s+/, '').strip
    next if text.empty?
    unless text.start_with?('[ASSUMPTION]', '[CONFIRMED]')
      fail!(failures, "Assumptions 条目须以 [ASSUMPTION] 或 [CONFIRMED] 开头: #{text[0,60]}...")
    end
  end
end

if failures.empty?
  puts "GATE-SPEC-COVERAGE: PASS — spec 覆盖度与 Input Q&A 已确认 (#{spec_path})"
  exit 0
else
  warn "GATE-SPEC-COVERAGE: FAIL —"
  failures.each { |f| warn "  - #{f}" }
  warn "GATE-SPEC-COVERAGE: BLOCKED — 完成 Post-Draft Ping、Input Q&A、spec-coverage.yml 后重跑" 
  exit 1
end
RUBY
