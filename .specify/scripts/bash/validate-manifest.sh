#!/usr/bin/env bash
# Validate *-manifest.yml under WORK_ROOT (paths exist, no duplicate gate_aggregate_extra).
#
# Usage: validate-manifest.sh [--work-root DIR]
# Exit:  0 pass  1 fail  2 setup error

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

WORK_ROOT_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-root) WORK_ROOT_ARG="$2"; shift 2 ;;
        -h|--help) echo "Usage: validate-manifest.sh [--work-root DIR]"; exit 0 ;;
        *) echo "Unknown: $1" >&2; exit 2 ;;
    esac
done

_paths=$(get_feature_paths) || exit 2
eval "$_paths"

ROOT="${WORK_ROOT_ARG:-${WORK_ROOT:-${SPEC_DIM_DIR:-${FEATURE_DIR}}}}"
[[ "$ROOT" != /* ]] && ROOT="$(get_repo_root)/$ROOT"

command -v ruby >/dev/null 2>&1 || { echo "VALIDATE-MANIFEST: ERROR requires ruby" >&2; exit 2; }

export VAL_WORK_ROOT="$ROOT"
export VAL_MODULE_DIR="${MODULE_DIR:-}"
export VAL_CHARTER_DIR="${CHARTER_DIR:-}"

ruby <<'RUBY'
require 'yaml'
require 'pathname'

work_root = ENV.fetch('VAL_WORK_ROOT')
module_dir = ENV['VAL_MODULE_DIR'].to_s
charter_dir = ENV['VAL_CHARTER_DIR'].to_s
failures = []
root = Pathname.new(work_root)

manifest_path = nil
cur = root
loop do
  %w[spec-manifest.yml plan-manifest.yml].each do |name|
    cand = cur.join(name)
    manifest_path = cand if cand.file?
  end
  break if manifest_path
  break if cur.root? || cur.to_s == '/'
  cur = cur.parent
end

unless manifest_path&.file?
  puts 'VALIDATE-MANIFEST: skip (no manifest under work root)'
  exit 0
end

manifest = YAML.load_file(manifest_path) || {}
base = manifest_path.dirname
index_name = manifest['index'] || 'spec.md'
idx = base.join(index_name)
failures << "missing index: #{idx}" unless idx.file?

def expand_shard(base, rel)
  out = []
  if rel.to_s.include?('*')
    Dir.glob(base.join(rel).to_s).each { |g| out << Pathname.new(g) }
  else
    out << base.join(rel)
  end
  out
end

all_paths = []
includes = manifest['includes'] || {}
%w[module charter].each do |scope|
  (includes[scope] || []).each do |rel|
    base_dir = scope == 'module' ? module_dir : charter_dir
    if base_dir.empty?
      failures << "includes.#{scope} set but #{scope}_DIR unknown: #{rel}"
      next
    end
    p = Pathname.new(base_dir).join(rel)
    failures << "missing includes.#{scope}: #{p}" unless p.file?
    all_paths << p.to_s if p.file?
  end
end

(manifest['shards'] || {}).each do |key, rel|
  expand_shard(base, rel).each do |p|
    failures << "missing shard #{key}: #{p}" unless p.file?
    all_paths << p.to_s if p.file?
  end
end

(manifest['gate_aggregate_extra'] || []).each do |rel|
  p = base.join(rel)
  if all_paths.include?(p.to_s)
    failures << "gate_aggregate_extra duplicates includes/shards: #{rel}"
  end
  failures << "missing gate_aggregate_extra: #{p}" unless p.file?
end

if failures.empty?
  puts 'VALIDATE-MANIFEST: PASS'
  exit 0
else
  puts 'VALIDATE-MANIFEST: FAIL'
  failures.each { |f| puts "  - #{f}" }
  exit 1
end
RUBY
