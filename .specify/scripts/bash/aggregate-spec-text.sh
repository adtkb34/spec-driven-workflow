#!/usr/bin/env bash
# Concatenate manifest index + includes + shards (+ optional extra) for gate aggregation.
#
# Usage: aggregate-spec-text.sh [--work-root DIR]
# Env:   WORK_ROOT, or resolves via get_feature_paths / SPECIFY_FEATURE_DIRECTORY
# Exit:  0 prints aggregated text to stdout; 2 on setup error

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

WORK_ROOT_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-root) WORK_ROOT_ARG="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: aggregate-spec-text.sh [--work-root DIR]"
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

_paths=$(get_feature_paths) || exit 2
eval "$_paths"
unset _paths

ROOT="${WORK_ROOT_ARG:-${WORK_ROOT:-${SPEC_DIM_DIR:-${FEATURE_DIR}}}}"
[[ -n "$ROOT" ]] || { echo "aggregate-spec-text: no work root" >&2; exit 2; }
[[ "$ROOT" != /* ]] && ROOT="$(get_repo_root)/$ROOT"

command -v ruby >/dev/null 2>&1 || { echo "aggregate-spec-text: requires ruby" >&2; exit 2; }

export AGG_WORK_ROOT="$ROOT"
export AGG_MODULE_DIR="${MODULE_DIR:-}"
export AGG_CHARTER_DIR="${CHARTER_DIR:-}"

ruby <<'RUBY'
# frozen_string_literal: true
require 'yaml'
require 'pathname'

work_root = ENV.fetch('AGG_WORK_ROOT')
module_dir = ENV['AGG_MODULE_DIR'].to_s
charter_dir = ENV['AGG_CHARTER_DIR'].to_s
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
  idx = root.join('spec.md')
  idx = root.join('plan.md') unless idx.file?
  print idx.read(encoding: 'UTF-8') if idx.file?
  exit 0
end

manifest = YAML.load_file(manifest_path) || {}
index_name = manifest['index'] || (manifest_path.basename.to_s.include?('plan') ? 'plan.md' : 'spec.md')
base = manifest_path.dirname
paths = []
paths << base.join(index_name) if base.join(index_name).file?

includes = manifest['includes'] || {}
%w[module charter].each do |scope|
  rels = includes[scope] || []
  base_dir = scope == 'module' ? module_dir : charter_dir
  next if base_dir.empty?
  rels.each do |rel|
    p = Pathname.new(base_dir).join(rel)
    paths << p if p.file?
  end
end

shards = manifest['shards'] || {}
shards.each_value do |rel|
  if rel.to_s.include?('*')
    Dir.glob(base.join(rel).to_s).sort.each { |g| paths << Pathname.new(g) }
  else
    p = base.join(rel)
    paths << p if p.file?
  end
end

extra = manifest['gate_aggregate_extra'] || []
extra.each do |rel|
  p = rel.to_s.start_with?('/') ? Pathname.new(rel) : base.join(rel)
  paths << p if p.file?
end

seen = {}
paths.uniq.each do |p|
  next unless p.file?
  key = p.realpath.to_s
  next if seen[key]
  seen[key] = true
  print "\n\n--- FILE: #{p} ---\n\n"
  print p.read(encoding: 'UTF-8')
end
RUBY
