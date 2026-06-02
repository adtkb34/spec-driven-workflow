#!/usr/bin/env bash
# Executable gate: tech-stack confirmation.
# Enforces that the tech-stack gate actually ran and the user confirmed a stack
# before plan body / tasks / implement proceed. The confirmation is materialized
# as FEATURE_DIR/stack.yml with `confirmed: true`.
#
# Usage: ./gate-stack.sh
# Exit:  0 = stack confirmed   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Run-log self-record: the exit code captured here is machine truth (model cannot edit it).
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-STACK: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

STACK_FILE="$FEATURE_DIR/stack.yml"

if [[ ! -f "$STACK_FILE" ]]; then
    echo "GATE-STACK: BLOCKED — 未找到 $STACK_FILE" >&2
    echo "  进入 plan 前必须先过技术栈闸门并写出 stack.yml(见 .specify/memory/constitution.md)。" >&2
    exit 1
fi

# Require an explicit `confirmed: true` line (user pointed-and-nodded the stack).
if ! grep -qE '^[[:space:]]*confirmed:[[:space:]]*true[[:space:]]*$' "$STACK_FILE"; then
    echo "GATE-STACK: BLOCKED — $STACK_FILE 缺少 'confirmed: true'(技术栈方向尚未经用户确认)" >&2
    exit 1
fi

# Require a non-empty form field (drives verify profile + dimension activation).
if ! grep -qE '^[[:space:]]*form:[[:space:]]*\S+' "$STACK_FILE"; then
    echo "GATE-STACK: BLOCKED — $STACK_FILE 缺少 'form:'(web|cli|service|library|pipeline)" >&2
    exit 1
fi

echo "GATE-STACK: PASS — 技术栈已确认 ($STACK_FILE)"
exit 0
