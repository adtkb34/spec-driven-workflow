#!/usr/bin/env bash
# DORA report — aggregate the deploy/release markers the workflow already records
# (release-profiles.md 原则 7：每次 deliver/release 留 timestamp+git_sha+outcome) into the
# four/five DORA metrics. Read-only; this is a REPORT, not a gate.
#
# Evidence sources (all best-effort; missing data is reported as such, never faked):
#   • .releases/<version>/{release.yml,release.md,run-log.md}  → 生产上线(release)
#   • specs/<feature>/deliver.md                               → 交付(deliver)
#   • specs/*/run-log.md + .releases/*/run-log.md (GATE 行)    → 门通过/失败(返工代理)
#   • RELEASES.md 账本(若存在)                                 → 账本对照
#
# Outcome 解析：release.md / 账本里出现 rollback/回滚 → rollback；fail/失败 → fail；否则 success。
# version 形如 YYYYMMDD-HHMMSS-<sha> 时用于推断部署频率的时间分布。
#
# Usage:  dora-report.sh [--write]      # --write 同时落盘 .releases/DORA.md
# Exit:   0 always (report tool); 2 on setup error.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)" || { echo "DORA: ERROR resolving repo root" >&2; exit 2; }

WRITE=0
for a in "$@"; do [[ "$a" == "--write" ]] && WRITE=1; done

# ── collect ────────────────────────────────────────────────────────────────
releases_total=0
releases_success=0
releases_failed=0     # fail | rollback
deliveries=0
gate_total=0
gate_fail=0
first_ts=""
last_ts=""

note_ts() {  # track earliest/latest YYYYMMDD-HHMMSS token
    local t="$1"
    [[ -z "$t" ]] && return
    [[ -z "$first_ts" || "$t" < "$first_ts" ]] && first_ts="$t"
    [[ -z "$last_ts"  || "$t" > "$last_ts"  ]] && last_ts="$t"
}

# releases
if [[ -d "$REPO_ROOT/.releases" ]]; then
    while IFS= read -r ryml; do
        [[ -z "$ryml" ]] && continue
        rdir="$(dirname "$ryml")"
        releases_total=$((releases_total + 1))
        ver="$(basename "$rdir")"
        # ts token from version name (YYYYMMDD-HHMMSS-...)
        tok="$(printf '%s' "$ver" | grep -oE '[0-9]{8}-[0-9]{6}' | head -n1 || true)"
        note_ts "${tok//-/}"
        outcome="success"
        rmd="$rdir/release.md"
        if [[ -f "$rmd" ]]; then
            if grep -qiE 'rollback|回滚|reverted' "$rmd"; then outcome="rollback"
            elif grep -qiE '\boutcome:[[:space:]]*(fail|failed)\b|发布失败|上线失败' "$rmd"; then outcome="fail"
            fi
        fi
        if [[ "$outcome" == "success" ]]; then
            releases_success=$((releases_success + 1))
        else
            releases_failed=$((releases_failed + 1))
        fi
    done < <(find "$REPO_ROOT/.releases" -mindepth 2 -maxdepth 2 -name 'release.yml' 2>/dev/null)
fi

# deliveries
if [[ -d "$REPO_ROOT/specs" ]]; then
    while IFS= read -r _; do deliveries=$((deliveries + 1)); done \
        < <(find "$REPO_ROOT/specs" -mindepth 2 -maxdepth 2 -name 'deliver.md' 2>/dev/null)
fi

# gate runs (rework proxy) — scan run-log.md GATE lines
while IFS= read -r logf; do
    [[ -f "$logf" ]] || continue
    n_total=$(grep -cE '\*\*GATE\*\*' "$logf" 2>/dev/null || echo 0)
    n_fail=$(grep -cE '\*\*GATE\*\*.*FAIL' "$logf" 2>/dev/null || echo 0)
    gate_total=$((gate_total + n_total))
    gate_fail=$((gate_fail + n_fail))
done < <(find "$REPO_ROOT/specs" "$REPO_ROOT/.releases" -name 'run-log.md' 2>/dev/null)

# ── derive ───────────────────────────────────────────────────────────────────
pct() {  # pct <num> <den>
    local n="$1" d="$2"
    [[ "$d" -eq 0 ]] && { echo "n/a"; return; }
    awk -v n="$n" -v d="$d" 'BEGIN{ printf "%.0f%%", (n/d)*100 }'
}
cfr="$(pct "$releases_failed" "$releases_total")"
rework="$(pct "$gate_fail" "$gate_total")"

span="n/a"
if [[ -n "$first_ts" && -n "$last_ts" && "$first_ts" != "$last_ts" ]]; then
    span="$first_ts → $last_ts"
fi

# ── render ───────────────────────────────────────────────────────────────────
render() {
cat <<MD
# DORA 报表 — $(basename "$REPO_ROOT")

> 由 \`.specify/scripts/bash/dora-report.sh\` 聚合 deliver/release 标记与 run-log 门事件。
> 生成时间: $(date '+%Y-%m-%d %H:%M:%S')。**缺数据如实标 n/a,不臆造**(对齐「验证而非声称」)。

## 原始计数

| 指标 | 值 | 来源 |
|------|----|------|
| 生产上线(release) 总数 | $releases_total | \`.releases/*/release.yml\` |
| ├ 成功 | $releases_success | release.md outcome |
| └ 失败/回滚 | $releases_failed | release.md (rollback/fail) |
| 交付(deliver) 总数 | $deliveries | \`specs/*/deliver.md\` |
| 门运行总数 / 失败 | $gate_total / $gate_fail | run-log GATE 行 |
| 记录时间跨度 | $span | version 时间戳 |

## DORA 五指标（best-effort）

| # | 指标 | 当前值 | 说明 |
|---|------|--------|------|
| 1 | 部署频率 | release=$releases_total · deliver=$deliveries | 跨度 $span;接 CI 后可换算每周/每日频次 |
| 2 | 变更前置时间(Lead Time) | n/a | 需 commit→上线时间戳;deliver/release 标记补 \`first_commit_ts\` 后可算 |
| 3 | 变更失败率(CFR) | $cfr | 失败/回滚 release ÷ release 总数 |
| 4 | 失败恢复时间(MTTR) | n/a | 需事故起止时间;rollback 记 \`detected_ts\`/\`restored_ts\` 后可算 |
| 5 | 返工率(rework 代理) | $rework | 门 FAIL ÷ 门总运行(非严格 DORA,作内部返工信号) |

> 要让 2/4 可计算：在 \`release.md\`/\`deliver.md\` 的部署标记里补 \`first_commit_ts\` 与
> rollback 的 \`detected_ts\`/\`restored_ts\`(release-profiles.md 原则 7 的扩展)。
MD
}

render
if [[ "$WRITE" -eq 1 ]]; then
    mkdir -p "$REPO_ROOT/.releases"
    render > "$REPO_ROOT/.releases/DORA.md"
    echo ""
    echo "DORA: 已写入 $REPO_ROOT/.releases/DORA.md"
fi
exit 0
