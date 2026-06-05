#!/usr/bin/env bash
# Print one path per line for AI read scope: read_scope.<phase> + filtered includes + shards.
#
# Usage: spec-read-scope.sh --phase <charter|specify|clarify|plan|tasks|implement|verify>
# Exit:  0 lists paths (relative to repo root when possible); 2 setup error

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

PHASE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase) PHASE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: spec-read-scope.sh --phase <phase>"
            exit 0
            ;;
        *) echo "Unknown: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$PHASE" ]] || { echo "spec-read-scope: --phase required" >&2; exit 2; }

_paths=$(get_feature_paths) || exit 2
eval "$_paths"

ROOT="${WORK_ROOT:-${SPEC_DIM_DIR:-${FEATURE_DIR}}}"
repo_root=$(get_repo_root)
[[ "$ROOT" != /* ]] && ROOT="$repo_root/$ROOT"

command -v ruby >/dev/null 2>&1 || { echo "spec-read-scope: requires ruby" >&2; exit 2; }

export SCOPE_WORK_ROOT="$ROOT"
export SCOPE_PHASE="$PHASE"
export SCOPE_MODULE_DIR="${MODULE_DIR:-}"
export SCOPE_CHARTER_DIR="${CHARTER_DIR:-}"
export SCOPE_REPO_ROOT="$repo_root"
export SCOPE_PLAN_DIR="${PLAN_DIR:-}"
export SCOPE_TASK_DIR="${TASK_DIR:-}"

ruby <<'RUBY'
require 'yaml'
require 'pathname'

work_root = Pathname.new(ENV.fetch('SCOPE_WORK_ROOT'))
phase = ENV.fetch('SCOPE_PHASE')
module_dir = ENV['SCOPE_MODULE_DIR'].to_s
charter_dir = ENV['SCOPE_CHARTER_DIR'].to_s
repo = Pathname.new(ENV.fetch('SCOPE_REPO_ROOT'))
plan_dir = ENV['SCOPE_PLAN_DIR'].to_s
task_dir = ENV['SCOPE_TASK_DIR'].to_s

manifest_path = nil
cur = work_root
loop do
  %w[spec-manifest.yml plan-manifest.yml].each do |name|
    cand = cur.join(name)
    manifest_path = cand if cand.file?
  end
  break if manifest_path
  break if cur.root? || cur.to_s == '/'
  cur = cur.parent
end

paths = []
if manifest_path&.file?
  manifest = YAML.load_file(manifest_path) || {}
  base = manifest_path.dirname
  rs = manifest['read_scope'] || {}
  (rs[phase] || rs[phase.to_sym] || []).each do |rel|
    p = base.join(rel)
    paths << p if p.file?
  end

  # Phase-filtered includes: specify/clarify get module+charter shared; plan omits tasks
  includes = manifest['includes'] || {}
  allow_includes = %w[charter specify clarify plan analyze].include?(phase)
  if allow_includes
  %w[module charter].each do |scope|
    next if phase == 'plan' && scope == 'module' # plan phase: charter shared only by default
    (includes[scope] || []).each do |rel|
      base_dir = scope == 'module' ? module_dir : charter_dir
      next if base_dir.empty?
      p = Pathname.new(base_dir).join(rel)
      paths << p if p.file?
    end
  end
  end

  if %w[clarify specify].include?(phase)
    (manifest['shards'] || {}).each do |_k, rel|
      if rel.to_s.include?('*')
        Dir.glob(base.join(rel).to_s).each { |g| paths << Pathname.new(g) }
      else
        p = base.join(rel)
        paths << p if p.file?
      end
    end
  end
else
  %w[spec.md plan.md charter.md].each do |name|
    p = work_root.join(name)
    paths << p if p.file?
  end
end

# Exclude task files for plan phase
if phase == 'plan' && !task_dir.empty?
  task_base = Pathname.new(task_dir)
  paths.reject! { |p| p.to_s.start_with?(task_base.to_s) }
end

seen = {}
paths.uniq.sort_by(&:to_s).each do |p|
  key = p.realpath.to_s
  next if seen[key]
  seen[key] = true
  rel = p.relative_path_from(repo) rescue p.to_s
  puts rel.to_s.gsub('\\', '/')
end
RUBY
