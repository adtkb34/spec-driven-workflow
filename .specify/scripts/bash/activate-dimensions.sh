#!/usr/bin/env bash
# Deterministic conditional-dimension activation.
# Reads FEATURE_DIR/stack.yml + .cursor/registry.yaml and prints the conditional
# dimensions whose `activate_if` is satisfied by the confirmed stack. Replaces the
# subjective "does this project count as backend?" vibe with a machine check.
#
# activate_if entry grammar (per registry dimension):
#   - bareFlag        -> stack[bareFlag] must be truthy (true)
#   - key=value       -> stack[key] must equal value (e.g. cloud=gcp)
# A dimension activates only if ALL its entries are satisfied (AND).
#
# Usage: ./activate-dimensions.sh [--phase <specify|clarify|plan|analyze|tasks|implement|verify>] [--json]
# Output (stdout): one activated dimension name per line (or JSON array with --json).
# Exit: 0 ok   2 setup error

set -uo pipefail

PHASE=""
JSON=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase) PHASE="${2:-}"; shift 2 ;;
        --json) JSON=true; shift ;;
        *) echo "activate-dimensions: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

_paths_output=$(get_feature_paths) || { echo "activate-dimensions: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

STACK_FILE="$FEATURE_DIR/stack.yml"
REGISTRY="$REPO_ROOT/.cursor/registry.yaml"

[[ -f "$STACK_FILE" ]] || { echo "activate-dimensions: ERROR $STACK_FILE not found (run plan tech-stack gate first)" >&2; exit 2; }
[[ -f "$REGISTRY" ]]   || { echo "activate-dimensions: ERROR $REGISTRY not found" >&2; exit 2; }

command -v ruby >/dev/null 2>&1 || { echo "activate-dimensions: ERROR requires 'ruby' (with built-in yaml)" >&2; exit 2; }

STACK_FILE="$STACK_FILE" REGISTRY="$REGISTRY" PHASE="$PHASE" JSON="$JSON" ruby <<'RUBY'
require 'yaml'

stack    = YAML.load_file(ENV['STACK_FILE']) || {}
registry = YAML.load_file(ENV['REGISTRY'])   || {}
phase    = ENV['PHASE'].to_s.strip
as_json  = ENV['JSON'] == 'true'

def truthy?(v)
  v == true || v.to_s.strip.downcase == 'true'
end

dims = (registry['dimensions'] || {})
activated = []

dims.each do |name, spec|
  next unless spec.is_a?(Hash)
  cond = spec['activate_if']
  next if cond.nil?            # not a conditional dimension
  cond = [cond] unless cond.is_a?(Array)

  ok = cond.all? do |entry|
    e = entry.to_s
    if e.include?('=')
      k, val = e.split('=', 2)
      stack[k.strip].to_s.strip == val.strip
    else
      truthy?(stack[e.strip])
    end
  end
  next unless ok

  if !phase.empty?
    bp = spec['bind_phase'] || []
    next unless bp.include?(phase)
  end
  activated << name
end

if as_json
  require 'json'
  puts JSON.generate(activated)
else
  activated.each { |d| puts d }
end
RUBY
