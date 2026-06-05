#!/usr/bin/env bash
# Executable gate: charter confirmation before specify.
# Materialized as FEATURE_DIR/charter.yml with confirmed: true + charter.md content.
#
# Usage: ./gate-charter.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-CHARTER: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

CHARTER_YML="$FEATURE_DIR/charter.yml"
CHARTER_MD="$FEATURE_DIR/charter.md"
fail=0

_is_confirmed_true() {
    local f="$1"
    grep -qE '^[[:space:]]*confirmed:[[:space:]]*true[[:space:]]*($|#)' "$f"
}

if [[ ! -f "$CHARTER_YML" ]]; then
    echo "GATE-CHARTER: BLOCKED — 未找到 $CHARTER_YML" >&2
    echo "  进入 specify 前须完成 /speckit-charter 并写出 charter.yml。" >&2
    exit 1
fi

if ! _is_confirmed_true "$CHARTER_YML"; then
    echo "GATE-CHARTER: BLOCKED — $CHARTER_YML 的 confirmed 须为 true（章程尚未经用户确认）" >&2
    fail=1
fi

if ! grep -qE '^[[:space:]]*complexity:[[:space:]]*(trivial|standard|complex)[[:space:]]*($|#)' "$CHARTER_YML"; then
    echo "GATE-CHARTER: BLOCKED — $CHARTER_YML 缺少 complexity:(trivial|standard|complex)" >&2
    fail=1
fi

if [[ ! -f "$CHARTER_MD" ]]; then
    echo "GATE-CHARTER: BLOCKED — 未找到 $CHARTER_MD" >&2
    fail=1
fi

if [[ -f "$CHARTER_MD" ]]; then
    if ! grep -qE '^## Core Business Logic' "$CHARTER_MD"; then
        echo "GATE-CHARTER: BLOCKED — charter.md 缺少 ## Core Business Logic 节" >&2
        fail=1
    fi
    patterns=(
        '[Background, goals'
        '[Background, stakeholders'
        '[Describe stakeholders'
        '[FEATURE NAME]'
        '[DATE]'
        '[Step 1]'
        '[Rule 1]'
        '[Coarse capability'
        '[Direction the user approved]'
    )
    complexity=$(grep -E '^[[:space:]]*complexity:[[:space:]]*(trivial|standard|complex)' "$CHARTER_YML" 2>/dev/null \
        | sed -E 's/.*complexity:[[:space:]]*//' | tr -d ' ')
    if [[ "$complexity" == "standard" || "$complexity" == "complex" ]]; then
        if ! grep -qE '^## Approach Trade-offs' "$CHARTER_MD"; then
            echo "GATE-CHARTER: BLOCKED — standard/complex 的 charter.md 须含 ## Approach Trade-offs" >&2
            fail=1
        fi
    fi
    for pat in "${patterns[@]}"; do
        if grep -qF "$pat" "$CHARTER_MD"; then
            echo "GATE-CHARTER: BLOCKED — charter.md 仍为模板占位: $pat" >&2
            fail=1
            break
        fi
    done
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-CHARTER: PASS — 立项章程已确认 ($CHARTER_MD)"
    exit 0
fi
echo "GATE-CHARTER: BLOCKED — 完成 charter 确认后重跑" >&2
exit 1
