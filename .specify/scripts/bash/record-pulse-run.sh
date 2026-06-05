#!/usr/bin/env bash
# Record a successful scheduled pulse (increment period quota).
# Usage: record-pulse-run.sh [--json]
# Exit: 0 ok   2 setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../../.." && pwd)"
SCHEDULE="${PULSE_SCHEDULE_FILE:-$REPO_ROOT/.specify/pulse-schedule.yml}"
STATE="${PULSE_SCHEDULE_STATE_FILE:-$REPO_ROOT/.specify/pulse-schedule-state.yml}"

command -v ruby >/dev/null 2>&1 || { echo "record-pulse-run: ERROR requires ruby" >&2; exit 2; }
[[ -f "$SCHEDULE" ]] || { echo "record-pulse-run: ERROR missing $SCHEDULE" >&2; exit 2; }

export SCHEDULE STATE JSON
ruby <<'RUBY'
require 'yaml'
require 'json'
require 'date'
require 'time'

sch = YAML.load_file(ENV['SCHEDULE']) || {}
cadence = sch['cadence'] || {}
preset = cadence['preset'].to_s
rounds = (cadence['rounds_per_period'] || 1).to_i
rounds = 1 if rounds < 1

period_id = case preset
when 'daily' then Date.today.strftime('%Y-%m-%d')
when 'biweekly'
  y = Date.today.cwyear
  w = Date.today.cweek
  bi = ((w - 1) / 2) + 1
  "#{y}-B#{bi}"
else
  Date.today.strftime('%G-W%V')
end

state_path = ENV['STATE']
state = File.exist?(state_path) ? (YAML.load_file(state_path) || {}) : {}
runs = state['runs_completed'].to_i
runs = 0 if state['period_id'].to_s != period_id
runs += 1

new_state = {
  'version' => 1,
  'period_id' => period_id,
  'runs_completed' => runs,
  'last_run_at' => Time.now.iso8601,
  'rounds_per_period' => rounds
}

File.write(state_path, new_state.to_yaml)

out = { 'period_id' => period_id, 'runs_completed' => runs, 'state_file' => state_path }
if ENV['JSON'] == 'true'
  puts JSON.pretty_generate(out)
else
  puts "record-pulse-run: OK period=#{period_id} runs_completed=#{runs}/#{rounds}"
end
RUBY
exit $?
