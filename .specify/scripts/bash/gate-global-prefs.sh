#!/usr/bin/env bash
# Executable gate: Principle VII context-isolation decision recorded.
# Blocks specify completion when global_prefs was never user-confirmed.
#
# PASS paths:
#   1. FEATURE_DIR/global-prefs.yml — decision + confirmed: true
#   2. Legacy: stack.yml has global_prefs (ignore|selective|adopt) and no global-prefs.yml
#
# Usage: ./gate-global-prefs.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-GLOBAL-PREFS: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

PREFS_FILE="$FEATURE_DIR/global-prefs.yml"
STACK_FILE="$FEATURE_DIR/stack.yml"

_has_valid_decision_in_file() {
    local f="$1"
    grep -qE '^[[:space:]]*decision:[[:space:]]*(ignore|selective|adopt)[[:space:]]*($|#)' "$f" \
        || grep -qE '^[[:space:]]*global_prefs:[[:space:]]*(ignore|selective|adopt)[[:space:]]*($|#)' "$f"
}

_is_confirmed_true() {
    local f="$1"
    grep -qE '^[[:space:]]*confirmed:[[:space:]]*true[[:space:]]*($|#)' "$f"
}

if [[ -f "$PREFS_FILE" ]]; then
    if ! _has_valid_decision_in_file "$PREFS_FILE"; then
        echo "GATE-GLOBAL-PREFS: BLOCKED — $PREFS_FILE 缺少 decision:(ignore|selective|adopt)" >&2
        echo "  环境隔离闸门：须在与用户确认后写入。" >&2
        exit 1
    fi
    if ! _is_confirmed_true "$PREFS_FILE"; then
        echo "GATE-GLOBAL-PREFS: BLOCKED — $PREFS_FILE 的 confirmed 须为 true（用户尚未确认环境隔离决策）" >&2
        echo "  specify 开场：扫描全局偏好来源 → 让用户选 ignore/selective/adopt → 再设 confirmed: true。" >&2
        exit 1
    fi
    if grep -qE '^[[:space:]]*decision:[[:space:]]*selective[[:space:]]*($|#)' "$PREFS_FILE"; then
        allow_count=$(awk '
            /^[[:space:]]*global_prefs_allow:/ { in_allow=1; next }
            in_allow && /^[[:space:]]*-/ { count++; next }
            in_allow && /^[^[:space:]#]/ { exit }
            END { print count+0 }
        ' "$PREFS_FILE")
        if [[ "${allow_count:-0}" -lt 1 ]]; then
            echo "GATE-GLOBAL-PREFS: BLOCKED — decision: selective 时 global_prefs_allow 须至少列一项" >&2
            exit 1
        fi
    fi
    echo "GATE-GLOBAL-PREFS: PASS — 环境隔离已确认 ($PREFS_FILE)"
    exit 0
fi

if [[ -f "$STACK_FILE" ]] && _has_valid_decision_in_file "$STACK_FILE"; then
    echo "GATE-GLOBAL-PREFS: PASS — legacy stack.yml global_prefs ($STACK_FILE)"
    echo "  提示：新特性请在 specify 开场写入 global-prefs.yml（confirmed: true）。" >&2
    exit 0
fi

echo "GATE-GLOBAL-PREFS: BLOCKED — 未找到已确认的环境隔离决策" >&2
echo "  需要 $PREFS_FILE（decision + confirmed: true），或（旧特性）$STACK_FILE 中的 global_prefs。" >&2
echo "  specify 开场必做：扫描 User Rules / AGENTS.md / Memories → 用户选 ignore|selective|adopt。" >&2
exit 1
