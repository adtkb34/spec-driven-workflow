#!/usr/bin/env bash
# Should a scheduled maintain pulse run now?
# Usage: check-pulse-schedule.sh [--json]
# Exit: 0 should run   1 should not   2 setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

REPO_ROOT="$(CDPATH="" cd "$SCRIPT_DIR/../../.." && pwd)"
SCHEDULE="${PULSE_SCHEDULE_FILE:-$REPO_ROOT/.specify/pulse-schedule.yml}"
STATE="${PULSE_SCHEDULE_STATE_FILE:-$REPO_ROOT/.specify/pulse-schedule-state.yml}"

command -v ruby >/dev/null 2>&1 || { echo "check-pulse-schedule: ERROR requires ruby" >&2; exit 2; }
[[ -f "$SCHEDULE" ]] || { echo "check-pulse-schedule: ERROR missing $SCHEDULE" >&2; exit 2; }

export SCHEDULE STATE REPO_ROOT JSON
ruby <<'RUBY'
require 'yaml'
require 'json'
require 'time'
require 'date'

schedule_path = ENV['SCHEDULE']
state_path = ENV['STATE']
repo = ENV['REPO_ROOT']
json_out = ENV['JSON'] == 'true'

sch = YAML.load_file(schedule_path) || {}
result = { 'should_run' => false, 'reason' => '', 'feature_directory' => '', 'round_index' => 0, 'focus' => 'experience' }

unless sch['enabled']
  result['reason'] = 'disabled'
  puts JSON.pretty_generate(result) if json_out
  exit 1
end

tz = sch['timezone'].to_s.strip
tz = 'Asia/Shanghai' if tz.empty?

now = if tz && !tz.empty?
  Time.now # local server; document that user should set TZ or use matching cron
else
  Time.now
end

pw = sch['project_window'] || {}
if pw['start_date'].to_s.strip != ''
  begin
    start_d = Date.parse(pw['start_date'].to_s)
    exit_now(result, json_out, 'before_project_start') if Date.today < start_d
  rescue ArgumentError
    exit_now(result, json_out, 'invalid_start_date')
  end
end
unless pw['end_date'].nil? || pw['end_date'].to_s.strip == '' || pw['end_date'].to_s == 'null'
  begin
    end_d = Date.parse(pw['end_date'].to_s)
    exit_now(result, json_out, 'after_project_end') if Date.today > end_d
  rescue ArgumentError
    exit_now(result, json_out, 'invalid_end_date')
  end
end

dw = sch['daily_window'] || {}
dow_map = { 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6, 'sun' => 0 }
allowed = (dw['days_of_week'] || []).map { |d| dow_map[d.to_s.downcase[0,3]] }.compact
if !allowed.empty?
  wday = Date.today.wday
  exit_now(result, json_out, 'day_not_allowed') unless allowed.include?(wday)
end

if dw['start'].to_s.strip != '' && dw['end'].to_s.strip != ''
  cur = now.strftime('%H:%M')
  exit_now(result, json_out, 'outside_daily_window') if cur < dw['start'].to_s || cur > dw['end'].to_s
end

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

state = File.exist?(state_path) ? (YAML.load_file(state_path) || {}) : {}
runs = state['runs_completed'].to_i
if state['period_id'].to_s != period_id
  runs = 0
end
if runs >= rounds
  exit_now(result, json_out, 'quota_exhausted')
end

round_times = cadence['round_times'] || []
round_index = runs + 1
if !round_times.empty?
  match = false
  round_times.each_with_index do |rt, i|
    next unless rt.is_a?(Hash)
    rt_dow = dow_map[rt['day_of_week'].to_s.downcase[0,3]]
    rt_h = rt['hour'].to_i
    rt_m = rt['minute'].to_i
    next unless Date.today.wday == rt_dow
    next unless now.hour == rt_h && now.min == rt_m
    match = true
    round_index = i + 1
    break
  end
  # Allow 15-minute window for cron skew
  unless match
    round_times.each_with_index do |rt, i|
      next unless rt.is_a?(Hash)
      rt_dow = dow_map[rt['day_of_week'].to_s.downcase[0,3]]
      next unless Date.today.wday == rt_dow
      rt_h = rt['hour'].to_i
      rt_m = rt['minute'].to_i
      slot = Time.new(now.year, now.month, now.day, rt_h, rt_m)
      if (now - slot).abs <= 900
        match = true
        round_index = i + 1
        break
      end
    end
  end
  exit_now(result, json_out, 'not_round_time') unless match
end

target = sch['target'] || {}
feat = target['feature_directory'].to_s.strip
if target['auto_latest_delivered'] && feat.empty?
  specs = File.join(repo, 'specs')
  if File.directory?(specs)
    dirs = Dir.children(specs).map { |d| File.join(specs, d) }.select { |p| File.directory?(p) && File.exist?(File.join(p, 'verify.md')) }
    feat = dirs.max_by { |p| File.mtime(p) }.to_s
    feat = feat.sub(%r{^#{Regexp.escape(repo)}/?}, '').gsub('\\', '/')
  end
end

if feat.empty?
  exit_now(result, json_out, 'no_target_feature')
end

pf = sch['pulse_focus'] || {}
focus_key = "round_#{round_index}"
focus = pf[focus_key] || pf['round_1'] || %w[experience new_demand priority regression][(round_index - 1) % 4]

result['should_run'] = true
result['reason'] = 'ok'
result['feature_directory'] = feat
result['round_index'] = round_index
result['focus'] = focus
result['period_id'] = period_id
result['runs_completed'] = runs
result['rounds_per_period'] = rounds

if json_out
  puts JSON.pretty_generate(result)
else
  puts "check-pulse-schedule: OK #{feat} round #{round_index} focus #{focus}"
end
exit 0

def exit_now(result, json_out, reason)
  result['reason'] = reason
  if json_out
    puts JSON.pretty_generate(result)
  else
    puts "check-pulse-schedule: skip (#{reason})"
  end
  exit 1
end
RUBY
exit $?
