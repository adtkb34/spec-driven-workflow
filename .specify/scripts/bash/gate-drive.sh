#!/usr/bin/env bash
# Executable gate: drive.yml consent and tier caps (meta — not on main P1 chain)
#
# Usage: ./gate-drive.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-DRIVE: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

DRIVE_YML="$FEATURE_DIR/drive.yml"
fail=0

if [[ ! -f "$DRIVE_YML" ]]; then
    echo "GATE-DRIVE: BLOCKED — 未找到 $DRIVE_YML（/speckit-drive 须 seed drive.yml）" >&2
    exit 1
fi

if ! grep -qE '^[[:space:]]*consent:[[:space:]]*true[[:space:]]*($|#)' "$DRIVE_YML"; then
    echo "GATE-DRIVE: BLOCKED — drive.yml 须 consent: true" >&2
    fail=1
fi

if ! grep -qE '^[[:space:]]*tier:[[:space:]]*(greenfield|maintain)[[:space:]]*($|#)' "$DRIVE_YML"; then
    echo "GATE-DRIVE: BLOCKED — drive.yml 缺少 tier:(greenfield|maintain)" >&2
    fail=1
fi

max_steps=$(grep -E '^[[:space:]]*max_auto_steps:' "$DRIVE_YML" 2>/dev/null | sed -E 's/.*max_auto_steps:[[:space:]]*//' | tr -d ' \r')
if [[ -n "$max_steps" && "$max_steps" =~ ^[0-9]+$ && "$max_steps" -eq 0 ]]; then
    echo "GATE-DRIVE: BLOCKED — max_auto_steps 为 0" >&2
    fail=1
fi

max_iter=$(grep -E '^[[:space:]]*max_iterations:' "$DRIVE_YML" 2>/dev/null | sed -E 's/.*max_iterations:[[:space:]]*//' | tr -d ' \r')
if [[ -n "$max_iter" && "$max_iter" =~ ^[0-9]+$ && "$max_iter" -eq 0 ]]; then
    echo "GATE-DRIVE: BLOCKED — max_iterations 为 0" >&2
    fail=1
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-DRIVE: PASS — drive 已授权 ($DRIVE_YML)"
    exit 0
fi
echo "GATE-DRIVE: BLOCKED — 修正 drive.yml 后重跑" >&2
exit 1
