#!/usr/bin/env bash
# Skill freshness + integrity scan over .cursor/registry.yaml.
# The registry pins capabilities by `source`/`origin`/`reviewed`, but a pinned
# `discovered` skill can drift upstream and a `reviewed:` date can silently age.
# This scan flags (a) skills whose review is older than the threshold and
# (b) registry paths (path/fallback_path/companion_path) that no longer resolve.
#
# Default is ADVISORY (exit 0, prints findings). Use --strict (or FRESHNESS_STRICT=1)
# to make stale/broken entries return non-zero so it can run as a periodic gate.
#
# Usage:  gate-skill-freshness.sh [--max-age-days N] [--strict]
# Exit:   0 = ok (or advisory)   1 = stale/broken found under --strict   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)" || { echo "FRESHNESS: ERROR resolving repo root" >&2; exit 2; }
REGISTRY="$REPO_ROOT/.cursor/registry.yaml"

MAX_AGE=180
STRICT="${FRESHNESS_STRICT:-0}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-age-days) MAX_AGE="${2:-180}"; shift 2 ;;
        --strict) STRICT=1; shift ;;
        *) shift ;;
    esac
done

[[ -f "$REGISTRY" ]] || { echo "FRESHNESS: ERROR 未找到 $REGISTRY" >&2; exit 2; }
command -v ruby >/dev/null 2>&1 || { echo "FRESHNESS: ERROR requires 'ruby'" >&2; exit 2; }

echo "FRESHNESS: 扫描 $REGISTRY (阈值 ${MAX_AGE} 天)"

# Ruby emits TSV: dim<TAB>kind<TAB>detail  where kind ∈ {STALE,MISSING,OK-AGE}
findings=$(REGISTRY="$REGISTRY" REPO_ROOT="$REPO_ROOT" MAX_AGE="$MAX_AGE" ruby -ryaml -e '
require "date"
reg = YAML.load_file(ENV["REGISTRY"]) || {}
dims = reg["dimensions"] || {}
max = ENV["MAX_AGE"].to_i
root = ENV["REPO_ROOT"].to_s
today = Date.today
resolve = ->(p) {
  return p if p.empty? || p.start_with?("/")
  File.join(root, p)
}
dims.each do |name, d|
  d ||= {}
  rv = d["reviewed"].to_s
  if rv =~ /\A\d{4}-\d{2}-\d{2}\z/
    begin
      age = (today - Date.parse(rv)).to_i
      puts "#{name}\tSTALE\treviewed #{rv} (#{age}d > #{max}d)" if age > max
    rescue ArgumentError
      puts "#{name}\tSTALE\treviewed 日期不可解析: #{rv}"
    end
  else
    puts "#{name}\tSTALE\t缺少/非法 reviewed 字段: #{rv.empty? ? "<empty>" : rv}"
  end
  %w[path fallback_path companion_path orchestration_path].each do |k|
    p = d[k].to_s
    next if p.empty?
    rp = resolve.call(p)
    puts "#{name}\tMISSING\t#{k}: #{p}" unless File.file?(rp)
  end
end
' 2>/dev/null)

stale=0; missing=0
if [[ -n "$findings" ]]; then
    while IFS=$'\t' read -r dim kind detail; do
        [[ -z "$dim" ]] && continue
        case "$kind" in
            STALE)   echo "  ⚠ STALE   [$dim] $detail"; stale=$((stale + 1)) ;;
            MISSING) echo "  ✗ MISSING [$dim] $detail"; missing=$((missing + 1)) ;;
        esac
    done <<< "$findings"
fi

echo "FRESHNESS: 过期复审 = $stale, 路径失效 = $missing"

if [[ "$missing" -gt 0 ]]; then
    echo "FRESHNESS: BLOCKED — 有 registry 路径失效(无论是否 --strict 都视为硬错误)" >&2
    exit 1
fi
if [[ "$stale" -gt 0 ]]; then
    if [[ "$STRICT" == "1" ]]; then
        echo "FRESHNESS: BLOCKED — --strict 下过期复审视为失败;请复审后更新 reviewed 日期" >&2
        exit 1
    fi
    echo "FRESHNESS: ADVISORY — 上述维度建议复审并更新 reviewed(非阻断)"
fi
echo "FRESHNESS: PASS"
exit 0
