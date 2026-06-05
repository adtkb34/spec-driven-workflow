#!/usr/bin/env bash
# Render cron expressions from .specify/pulse-schedule.yml cadence.
# Usage: render-pulse-cron.sh [--list]
#   --list  JSON array: [{round_index, cron, day_of_week, hour, minute, focus}]

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../../.." && pwd)"
SCHEDULE="${PULSE_SCHEDULE_FILE:-$REPO_ROOT/.specify/pulse-schedule.yml}"
LIST=false
[[ "${1:-}" == "--list" ]] && LIST=true

command -v ruby >/dev/null 2>&1 || { echo "render-pulse-cron: ERROR requires ruby" >&2; exit 2; }
[[ -f "$SCHEDULE" ]] || { echo "render-pulse-cron: ERROR missing $SCHEDULE" >&2; exit 2; }

export SCHEDULE LIST
ruby <<'RUBY'
require 'yaml'
require 'json'

sch = YAML.load_file(ENV['SCHEDULE']) || {}
cadence = sch['cadence'] || {}
pf = sch['pulse_focus'] || {}
dow_map = { 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6, 'sun' => 0 }

slots = []
round_times = cadence['round_times'] || []
if !round_times.empty?
  round_times.each_with_index do |rt, i|
    next unless rt.is_a?(Hash)
    dow = dow_map[rt['day_of_week'].to_s.downcase[0,3]] || 1
    h = rt['hour'].to_i
    m = rt['minute'].to_i
    idx = i + 1
    focus = pf["round_#{idx}"] || pf['round_1'] || 'experience'
    slots << {
      'round_index' => idx,
      'cron' => "#{m} #{h} * * #{dow}",
      'day_of_week' => rt['day_of_week'],
      'hour' => h,
      'minute' => m,
      'focus' => focus
    }
  end
else
  preset = cadence['preset'].to_s
  if preset == 'custom' && cadence['cron'].to_s.strip != ''
    slots << {
      'round_index' => 1,
      'cron' => cadence['cron'].to_s.strip,
      'day_of_week' => cadence['day_of_week'],
      'hour' => cadence['hour'],
      'minute' => cadence['minute'],
      'focus' => pf['round_1'] || 'experience'
    }
  else
    dow = dow_map[cadence['day_of_week'].to_s.downcase[0,3]] || 1
    h = (cadence['hour'] || 10).to_i
    m = (cadence['minute'] || 0).to_i
    n = (cadence['rounds_per_period'] || 1).to_i
    n = 1 if n < 1
    n.times do |i|
      idx = i + 1
      focus = pf["round_#{idx}"] || pf['round_1'] || 'experience'
      slots << {
        'round_index' => idx,
        'cron' => "#{m} #{h} * * #{dow}",
        'day_of_week' => cadence['day_of_week'] || 'mon',
        'hour' => h,
        'minute' => m,
        'focus' => focus
      }
    end
  end
end

if ENV['LIST'] == 'true'
  puts JSON.pretty_generate(slots)
else
  slots.each { |s| puts s['cron'] }
end
RUBY
exit $?
