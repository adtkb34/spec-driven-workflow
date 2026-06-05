#!/usr/bin/env bash
# Phase brief — P0 questions + live unlock status (no stored booleans in phase.yml).
# Usage:
#   phase-brief.sh [--phase <name>] [--questions-only] [--unlock-status] [--json] [--mode normal|amend|handoff|drive]
# Exit: 0 ok   2 setup error

set -uo pipefail

PHASE=""
QUESTIONS_ONLY=false
UNLOCK_STATUS=false
JSON=false
MODE="normal"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)           PHASE="${2:-}"; shift 2 ;;
        --questions-only)  QUESTIONS_ONLY=true; shift ;;
        --unlock-status)   UNLOCK_STATUS=true; shift ;;
        --json)            JSON=true; shift ;;
        --mode)            MODE="${2:-normal}"; shift 2 ;;
        -h|--help)
            sed -n '2,6p' "$0"
            exit 0
            ;;
        *) echo "phase-brief: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

_paths_output=$(get_feature_paths) || { echo "phase-brief: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

WORKFLOW_INDEX="$REPO_ROOT/.specify/workflows/workflow-index.yml"
PHASE_INDEX="$REPO_ROOT/.specify/workflows/phase-index.yml"
PHASE_FILE="$FEATURE_DIR/phase.yml"

command -v ruby >/dev/null 2>&1 || { echo "phase-brief: ERROR requires ruby (yaml)" >&2; exit 2; }
[[ -f "$WORKFLOW_INDEX" ]] || { echo "phase-brief: ERROR missing $WORKFLOW_INDEX" >&2; exit 2; }
[[ -f "$PHASE_INDEX" ]]   || { echo "phase-brief: ERROR missing $PHASE_INDEX" >&2; exit 2; }

# Resolve phase from phase.yml if omitted
if [[ -z "$PHASE" && -f "$PHASE_FILE" ]]; then
    PHASE=$(ruby -ryaml -e "puts((YAML.load_file('$PHASE_FILE') || {})['current_phase'].to_s.strip)" 2>/dev/null || true)
fi
[[ -n "$PHASE" ]] || { echo "phase-brief: ERROR --phase required (no current_phase in phase.yml)" >&2; exit 2; }

run_gate() {
    local script="$1"
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
        "$SCRIPT_DIR/$script" >/dev/null 2>&1
        return $?
    fi
    return 2
}

export REPO_ROOT FEATURE_DIR PHASE PHASE_FILE WORKFLOW_INDEX PHASE_INDEX MODE
export QUESTIONS_ONLY=$QUESTIONS_ONLY UNLOCK_STATUS=$UNLOCK_STATUS JSON=$JSON
export SCRIPT_DIR

ruby <<'RUBY'
require 'yaml'
require 'json'
require 'time'

repo     = ENV['REPO_ROOT']
feat     = ENV['FEATURE_DIR']
phase    = ENV['PHASE'].to_s.strip
mode     = ENV['MODE'].to_s.strip
wf       = YAML.load_file(ENV['WORKFLOW_INDEX']) || {}
pi       = YAML.load_file(ENV['PHASE_INDEX']) || {}
phase_yml = File.exist?(ENV['PHASE_FILE']) ? (YAML.load_file(ENV['PHASE_FILE']) || {}) : {}

phases_wf = wf['phases'] || {}
phases_pi = pi['phases'] || {}
modes_pi = pi['modes'] || {}
modes_wf = wf['modes'] || {}

if mode == 'drive'
  pi_entry = modes_pi['drive'] || {}
  wf_entry = modes_wf['drive'] || {}
  ceremony = pi_entry['ceremony'] || 'full'
elsif !phases_wf.key?(phase)
  warn "phase-brief: ERROR unknown phase '#{phase}'"
  exit 2
else
  wf_entry = phases_wf[phase] || {}
  pi_entry = phases_pi[phase] || {}
  ceremony = pi_entry['ceremony'] || wf_entry['ceremony'] || 'full'
end

def run_gate(script_dir, name)
  path = File.join(script_dir, name)
  return { 'name' => name, 'status' => 'missing', 'pass' => false } unless File.executable?(path)
  ok = system(path, out: File::NULL, err: File::NULL)
  { 'name' => name, 'status' => ok ? 'PASS' : 'FAIL', 'pass' => ok }
end

script_dir = ENV['SCRIPT_DIR']
gates = (wf_entry['gates_before_next'] || []).map { |g| run_gate(script_dir, g) }

# Live unlock hints for common transitions
unlock = {}
case phase
when 'charter'
  unlock['can_enter_specify'] = run_gate(script_dir, 'gate-charter.sh')[:pass]
when 'plan'
  unlock['can_enter_plan'] = run_gate(script_dir, 'gate-clarify.sh')[:pass] &&
                             run_gate(script_dir, 'gate-stack.sh')[:pass]
when 'implement'
  unlock['can_enter_implement'] = run_gate(script_dir, 'gate-analyze.sh')[:pass]
when 'deliver'
  unlock['can_enter_deliver'] = run_gate(script_dir, 'gate-verify.sh')[:pass]
when 'release'
  unlock['can_enter_release'] = run_gate(script_dir, 'gate-release.sh')[:pass] rescue false
end

out = {
  'phase' => phase,
  'mode' => mode,
  'feature_directory' => feat,
  'ceremony' => ceremony,
  'skill' => wf_entry['skill'],
  'model_tier' => wf_entry['model_tier'],
  'orchestration_chapters' => wf_entry['orchestration_chapters'] || [],
  'artifacts' => wf_entry['artifacts'] || [],
  'questions' => pi_entry['questions'] || [],
  'opening_order' => pi_entry['opening_order'] || [],
  'forbid_summary' => pi_entry['forbid_summary'] || [],
  'brainstorming_default' => pi_entry['brainstorming_default'],
  'gates_before_next' => gates,
  'unlock' => unlock,
  'phase_yml' => {
    'current_phase' => phase_yml['current_phase'],
    'last_gate_passed' => phase_yml['last_gate_passed'],
    'mode' => phase_yml['mode'] || 'normal'
  }
}

if mode == 'amend'
  out['amend_note'] = 'amend 模式：跳过 specify，须 gate-verify 后再改码'
  amend = (wf['modes'] || {})['amend'] || {}
  out['required_gate'] = amend['required_gate']
end

if mode == 'handoff'
  out['handoff_note'] = 'handoff：读 phase.yml + unlock-status，勿从零 specify'
end

PHASE_ORDER = %w[charter specify clarify plan analyze tasks implement verify deliver release]

if mode == 'drive'
  drive_yml = File.join(feat, 'drive.yml')
  drive = File.exist?(drive_yml) ? (YAML.load_file(drive_yml) || {}) : {}
  out['drive'] = {
    'tier' => drive['tier'],
    'auto_advance' => drive['auto_advance'],
    'consent' => drive['consent'],
    'max_auto_steps' => drive['max_auto_steps'],
    'max_iterations' => drive['max_iterations'],
    'current_iteration' => drive['current_iteration'],
    'pause_at' => drive['pause_at'] || []
  }
  out['skill'] = wf_entry['skill'] if wf_entry['skill']
  out['orchestration_chapters'] = wf_entry['orchestration_chapters'] || []
  cur = phase_yml['current_phase'].to_s.strip
  cur = 'charter' if cur.empty?
  idx = PHASE_ORDER.index(cur) || 0
  next_phase = nil
  (idx...PHASE_ORDER.size).each do |i|
    cand = PHASE_ORDER[i]
    entry = phases_wf[cand]
    next unless entry
    gs = (entry['gates_before_next'] || [])
    all_pass = gs.all? { |g| run_gate(script_dir, g)[:pass] }
    if cand == cur
      next_phase = PHASE_ORDER[i + 1] if all_pass && i + 1 < PHASE_ORDER.size
    elsif !all_pass
      next_phase = cand
      break
    end
  end
  next_phase ||= PHASE_ORDER[idx + 1] if idx + 1 < PHASE_ORDER.size
  out['drive']['current_phase'] = cur
  out['drive']['suggested_next_phase'] = next_phase
  gate_drive = run_gate(script_dir, 'gate-drive.sh')
  out['drive']['gate_drive'] = gate_drive[:status]
  if drive['tier'].to_s == 'maintain'
    out['drive']['maintain_note'] = 'maintain：pulse → iteration-queue → amend（须 gate-verify）'
  end
end

if ENV['JSON'] == 'true'
  puts JSON.pretty_generate(out)
  exit 0
end

if ENV['QUESTIONS_ONLY'] == 'true'
  puts "## P0 · #{phase} 自检提问（只问不答）"
  out['questions'].each_with_index { |q, i| puts "#{i + 1}. #{q}" }
  exit 0
end

if ENV['UNLOCK_STATUS'] == 'true'
  title = mode == 'drive' ? 'drive' : phase
  puts "## #{title} · unlock-status（实时 gate，非 phase.yml 缓存）"
  gates.each { |g| puts "- #{g['name']}: #{g['status']}" } unless gates.empty?
  unlock.each { |k, v| puts "- #{k}: #{v ? 'yes' : 'no'}" }
  if mode == 'drive' && out['drive']
    d = out['drive']
    puts "- tier: #{d['tier']}"
    puts "- gate-drive.sh: #{d['gate_drive']}"
    puts "- suggested_next_phase: #{d['suggested_next_phase']}"
    puts "- max_auto_steps: #{d['max_auto_steps']}"
  end
  exit 0
end

if mode == 'drive'
  puts "## Drive Brief · #{out['drive'] ? out['drive']['current_phase'] : phase}"
  if out['drive']
    d = out['drive']
    puts "- FEATURE_DIR: #{feat}"
    puts "- tier: #{d['tier']} | consent: #{d['consent']} | auto_advance: #{d['auto_advance']}"
    puts "- gate-drive.sh: #{d['gate_drive']}"
    puts "- suggested_next_phase: #{d['suggested_next_phase']}"
    puts "- max_auto_steps: #{d['max_auto_steps']} | max_iterations: #{d['max_iterations']}"
    puts "- skill: #{out['skill']}"
    puts ""
    puts "### P0 自检（drive meta）"
    out['questions'].each_with_index { |q, i| puts "#{i + 1}. #{q}" }
    unless out['forbid_summary'].empty?
      puts ""
      puts "### 禁止"
      out['forbid_summary'].each { |f| puts "- #{f}" }
    end
  end
  exit 0
end

# Default brief
puts "## Phase Brief · #{phase}"
puts "- FEATURE_DIR: #{feat}"
puts "- ceremony: #{ceremony} | model_tier: #{wf_entry['model_tier']}"
puts "- skill: #{wf_entry['skill']}"
puts "- mode: #{mode}"
puts ""
unless out['opening_order'].empty?
  puts "### specify 开场硬序（不可颠倒）"
  out['opening_order'].each { |s| puts "- #{s}" }
  puts ""
end
puts "### P0 自检（须自问，勿跳过）"
out['questions'].each_with_index { |q, i| puts "#{i + 1}. #{q}" }
if phase == 'specify'
  charter = run_gate(script_dir, 'gate-charter.sh')
  gpref = run_gate(script_dir, 'gate-global-prefs.sh')
  puts ""
  puts "### 上游 charter（实时）"
  puts "- gate-charter.sh: #{charter[:status]}#{charter[:status] == 'FAIL' ? ' ← 须先 /speckit-charter 并 confirmed:true' : ''}"
  puts ""
  puts "### 环境隔离门（实时）"
  puts "- gate-global-prefs.sh: #{gpref[:status]}#{gpref[:status] == 'FAIL' ? ' ← specify 开场须先问用户并写 global-prefs.yml' : ''}"
end
unless out['forbid_summary'].empty?
  puts ""
  puts "### 禁止"
  out['forbid_summary'].each { |f| puts "- #{f}" }
end
unless gates.empty?
  puts ""
  puts "### 下一阶段 gate（实时）"
  gates.each { |g| puts "- #{g['name']}: #{g['status']}" }
end
unless unlock.empty?
  puts ""
  puts "### unlock"
  unlock.each { |k, v| puts "- #{k}: #{v ? 'yes' : 'no'}" }
end
if ceremony == 'full'
  puts ""
  puts "（full ceremony：输出 5 行开场后等待用户「继续」再 Read skill 全文）"
elsif ceremony == 'session'
  puts ""
  puts "（session ceremony：本会话 implement 首次 5 行开场，后续仅 P0）"
end
RUBY
