#!/usr/bin/env bash
# Executable gate: clarification completeness.
# Blocks entry to /speckit-plan when the active spec still has unresolved
# ambiguity markers. Exit code is the source of truth — not model self-report.
#
# Usage: ./gate-clarify.sh
# Exit:  0 = clean (may proceed to plan)   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Run-log self-record: the exit code captured here is machine truth (model cannot edit it).
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-CLARIFY: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

if [[ ! -f "$FEATURE_SPEC" ]]; then
    echo "GATE-CLARIFY: ERROR spec.md not found at $FEATURE_SPEC (run /speckit-specify first)" >&2
    exit 2
fi

fail=0

# 1) Unresolved clarification markers.
if grep -nE '\[NEEDS CLARIFICATION' "$FEATURE_SPEC" >/dev/null 2>&1; then
    echo "GATE-CLARIFY: FAIL — spec 残留 [NEEDS CLARIFICATION]:"
    grep -nE '\[NEEDS CLARIFICATION' "$FEATURE_SPEC" | sed 's/^/    /'
    fail=1
fi

# 2) Leftover TODO / placeholder markers in the spec body.
if grep -nE '(\bTODO\b|\bTBD\b|\bFIXME\b|\[PLACEHOLDER\])' "$FEATURE_SPEC" >/dev/null 2>&1; then
    echo "GATE-CLARIFY: FAIL — spec 残留 TODO/TBD/FIXME/PLACEHOLDER:"
    grep -nE '(\bTODO\b|\bTBD\b|\bFIXME\b|\[PLACEHOLDER\])' "$FEATURE_SPEC" | sed 's/^/    /'
    fail=1
fi

if [[ "$fail" -eq 0 ]]; then
    if ! RUN_LOG_SUPPRESS=1 "$SCRIPT_DIR/gate-spec-coverage.sh" >/dev/null 2>&1; then
        echo "GATE-CLARIFY: FAIL — spec 业务覆盖度未确认(见 gate-spec-coverage.sh)"
        "$SCRIPT_DIR/gate-spec-coverage.sh" 2>&1 | sed 's/^/    /'
        fail=1
    fi
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-CLARIFY: PASS — spec 无残留模糊点且覆盖度已确认 ($FEATURE_SPEC)"
    exit 0
fi

echo "GATE-CLARIFY: BLOCKED — 先用 /speckit-clarify 消除上述模糊点再进入 /speckit-plan" >&2
exit 1
