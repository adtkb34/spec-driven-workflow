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
    echo "GATE-STACK: BLOCKED — $STACK_FILE 缺少 'form:'(web|desktop|cli|service|library|pipeline)" >&2
    exit 1
fi

# ui:true 表示有 GUI —— 不得误标为 cli（否则 verify 走 CLI 档、跳过窗口交互验收）。
if grep -qE '^[[:space:]]*ui:[[:space:]]*true' "$STACK_FILE" \
   && grep -qE '^[[:space:]]*form:[[:space:]]*cli[[:space:]]*' "$STACK_FILE"; then
    echo "GATE-STACK: BLOCKED — ui:true 时 form 不得为 cli；Tauri/Electron/桌面 GUI 请用 form:desktop" >&2
    echo "  见 .specify/memory/verify-profiles.md · desktop 档" >&2
    exit 1
fi

# 栈注明 Tauri/Electron 时禁止 form:cli（002 笔记类问题的根因之一）。
if grep -qiE 'tauri|electron' "$STACK_FILE" \
   && grep -qE '^[[:space:]]*form:[[:space:]]*cli[[:space:]]*' "$STACK_FILE"; then
    echo "GATE-STACK: BLOCKED — stack 含 Tauri/Electron 时 form 必须为 desktop(非 cli)" >&2
    exit 1
fi

# Principle VII 环境隔离闸门：standard/complex 必须显式记录 global_prefs 决策
# （ignore|selective|adopt），否则全局偏好的处置方式未经确认（默认隔离立场无据可查）。
# trivial 沿用既有栈时可省略（与快速通道一致）。
if ! grep -qE '^[[:space:]]*complexity:[[:space:]]*trivial[[:space:]]*$' "$STACK_FILE"; then
    if ! grep -qE '^[[:space:]]*global_prefs:[[:space:]]*(ignore|selective|adopt)[[:space:]]*$' "$STACK_FILE"; then
        echo "GATE-STACK: BLOCKED — $STACK_FILE 缺少 'global_prefs:'(ignore|selective|adopt)" >&2
        echo "  环境隔离闸门(Principle VII)：standard/complex 须显式记录全局偏好处置方式。" >&2
        exit 1
    fi
fi

echo "GATE-STACK: PASS — 技术栈已确认 ($STACK_FILE)"
exit 0
