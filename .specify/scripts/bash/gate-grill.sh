#!/usr/bin/env bash
# Executable gate: grill-with-docs closed before analyze.
# trivial: grill.yml waived:true + waived_reason
# standard/complex: grill.yml confirmed:true + grill-log.md no OPEN findings
#
# Usage: ./gate-grill.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-GRILL: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

GRILL_YML="$FEATURE_DIR/grill.yml"
GRILL_LOG="$FEATURE_DIR/grill-log.md"
CHARTER_YML="$FEATURE_DIR/charter.yml"
STACK_FILE="$FEATURE_DIR/stack.yml"
fail=0

_is_confirmed_true() {
    local f="$1"
    grep -qE '^[[:space:]]*confirmed:[[:space:]]*true[[:space:]]*($|#)' "$f"
}

_is_waived_true() {
    local f="$1"
    grep -qE '^[[:space:]]*waived:[[:space:]]*true[[:space:]]*($|#)' "$f"
}

_get_complexity() {
    local c=""
    if [[ -f "$CHARTER_YML" ]]; then
        c=$(grep -E '^[[:space:]]*complexity:[[:space:]]*(trivial|standard|complex)' "$CHARTER_YML" 2>/dev/null \
            | sed -E 's/.*complexity:[[:space:]]*//' | tr -d ' \r')
    fi
    if [[ -z "$c" && -f "$STACK_FILE" ]]; then
        c=$(grep -E '^[[:space:]]*complexity:[[:space:]]*(trivial|standard|complex)' "$STACK_FILE" 2>/dev/null \
            | sed -E 's/.*complexity:[[:space:]]*//' | tr -d ' \r')
    fi
    echo "$c"
}

complexity="$(_get_complexity)"

if [[ ! -f "$GRILL_YML" ]]; then
    if [[ "$complexity" == "trivial" ]]; then
        echo "GATE-GRILL: BLOCKED — trivial 须写 $GRILL_YML 且 waived:true + waived_reason" >&2
    else
        echo "GATE-GRILL: BLOCKED — 未找到 $GRILL_YML（plan 后须 grill-with-docs）" >&2
    fi
    exit 1
fi

if _is_waived_true "$GRILL_YML"; then
    if ! grep -qE '^[[:space:]]*waived_reason:[[:space:]]*.+' "$GRILL_YML"; then
        echo "GATE-GRILL: BLOCKED — waived:true 时 grill.yml 须有非空 waived_reason" >&2
        exit 1
    fi
    echo "GATE-GRILL: PASS — grill waived ($GRILL_YML)"
    exit 0
fi

if ! _is_confirmed_true "$GRILL_YML"; then
    echo "GATE-GRILL: BLOCKED — $GRILL_YML 的 confirmed 须为 true（或 trivial 设 waived:true）" >&2
    fail=1
fi

if [[ ! -f "$GRILL_LOG" ]]; then
    echo "GATE-GRILL: BLOCKED — 未找到 $GRILL_LOG" >&2
    fail=1
fi

if [[ -f "$GRILL_LOG" ]]; then
    if grep -qE '\|[[:space:]]*OPEN[[:space:]]*\|' "$GRILL_LOG"; then
        echo "GATE-GRILL: BLOCKED — grill-log.md 仍有 OPEN finding" >&2
        fail=1
    fi
    if ! grep -qE '^## Findings' "$GRILL_LOG"; then
        echo "GATE-GRILL: BLOCKED — grill-log.md 缺少 ## Findings" >&2
        fail=1
    fi
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-GRILL: PASS — 文档拷问已结案 ($GRILL_LOG)"
    exit 0
fi
echo "GATE-GRILL: BLOCKED — 完成 grill-with-docs 后重跑" >&2
exit 1
