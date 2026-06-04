#!/usr/bin/env bash
# Validate workflow-index.yml ↔ phase-index.yml ↔ registry bind_phase alignment.
# Exit: 0 ok   1 validation errors   2 setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../../.." && pwd)"
WF="$REPO_ROOT/.specify/workflows/workflow-index.yml"
PI="$REPO_ROOT/.specify/workflows/phase-index.yml"
REG="$REPO_ROOT/.cursor/registry.yaml"

command -v ruby >/dev/null 2>&1 || { echo "validate-workflow-index: ERROR requires ruby" >&2; exit 2; }
[[ -f "$WF" ]] || { echo "validate-workflow-index: ERROR missing workflow-index.yml" >&2; exit 2; }
[[ -f "$PI" ]] || { echo "validate-workflow-index: ERROR missing phase-index.yml" >&2; exit 2; }

export WF PI REG REPO_ROOT
ruby <<'RUBY'
require 'yaml'

wf = YAML.load_file(ENV['WF']) || {}
pi = YAML.load_file(ENV['PI']) || {}
reg = File.exist?(ENV['REG']) ? (YAML.load_file(ENV['REG']) || {}) : {}

errors = []
known_phases = %w[charter specify clarify plan analyze tasks implement verify deliver release]
wf_phases = wf['phases'] || {}
pi_phases = pi['phases'] || {}

known_phases.each do |p|
  errors << "workflow-index missing phase: #{p}" unless wf_phases.key?(p)
  errors << "phase-index missing phase: #{p}" unless pi_phases.key?(p)
end

(wf_phases.keys - known_phases).each { |k| errors << "workflow-index unknown phase: #{k}" }
(pi_phases.keys - known_phases).each { |k| errors << "phase-index unknown phase: #{k}" }

wf_phases.each do |name, spec|
  skill = spec['skill'].to_s
  if skill.empty?
    errors << "#{name}: missing skill path"
  elsif !File.exist?(File.join(ENV['REPO_ROOT'], skill.sub(%r{^\.?/?}, '')))
    errors << "#{name}: skill not found: #{skill}"
  end
  (spec['gates_before_next'] || []).each do |g|
    path = File.join(ENV['REPO_ROOT'], '.specify/scripts/bash', g)
    errors << "#{name}: gate script missing: #{g}" unless File.exist?(path)
  end
end

pi_phases.each do |name, spec|
  qs = spec['questions'] || []
  errors << "#{name}: no questions in phase-index" if qs.empty?
  c = spec['ceremony']
  errors << "#{name}: invalid ceremony #{c}" unless %w[full minimal session].include?(c.to_s)
end

# registry bind_phase should only reference known phases
(reg['dimensions'] || {}).each do |dim, spec|
  next unless spec.is_a?(Hash)
  binds = spec['bind_phase']
  next if binds.nil?
  list = binds.is_a?(Array) ? binds : [binds]
  list.each do |bp|
    errors << "registry dimension #{dim}: bind_phase #{bp} not in workflow-index" unless known_phases.include?(bp.to_s)
  end
end

if errors.empty?
  puts "validate-workflow-index: OK (#{wf_phases.size} phases)"
  exit 0
else
  errors.each { |e| warn "ERROR: #{e}" }
  exit 1
end
RUBY
