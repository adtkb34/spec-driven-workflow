#!/usr/bin/env bash
# Run Log — append a machine-grounded execution trace to FEATURE_DIR/run-log.md.
#
# Design intent (see workflow-orchestration.mdc · 运转日志):
#   The point of this log is AUDIT, not self-congratulation. So it separates two
#   kinds of records by trust level:
#     • GATE lines  → MACHINE TRUTH. Written by gate scripts' EXIT trap; the exit
#                     code is captured by the gate itself and cannot be edited by
#                     the model. These are real evidence.
#     • PHASE blocks → mostly SELF-REPORT. The orchestration layer states which
#                     model/skills/scripts it used (marked _(自述)_), which is a
#                     claim — NOT acceptance evidence. The one trustworthy part of
#                     a PHASE block is the ARTIFACT existence check, which this
#                     script performs mechanically against the filesystem.
#
# Subcommands:
#   run-log.sh gate <gate-name> <exit-code>
#       Append one machine-evidence line. Skipped when RUN_LOG_SUPPRESS is set
#       (used by gate-analyze.sh so its delegated sub-gate calls are not double-logged).
#
#   run-log.sh phase --phase NAME [--model M] [--skills CSV] [--scripts CSV] \
#                    [--artifacts CSV] [--note TEXT]
#       Append a phase block. model/skills/scripts/note are self-reported;
#       each artifact in --artifacts is verified for existence under FEATURE_DIR
#       (absolute paths allowed) and rendered ✓ / ✗.
#
# Never breaks its caller: if the feature directory cannot be resolved, the `gate`
# subcommand exits 0 silently; `phase` prints a warning and exits 2.
#
# Usage examples:
#   ./run-log.sh gate gate-stack.sh 0
#   ./run-log.sh phase --phase plan --model Opus --skills "api_design,data_modeling" \
#                --artifacts "plan.md,research.md,contracts" --note "确认 REST + Postgres"

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

resolve_log_file() {
    # Sets LOG_FILE and FEATURE_DIR. Returns 1 if feature dir cannot be resolved.
    local _paths
    _paths=$(get_feature_paths 2>/dev/null) || return 1
    eval "$_paths"
    [[ -n "${FEATURE_DIR:-}" && -d "$FEATURE_DIR" ]] || return 1
    LOG_FILE="$FEATURE_DIR/run-log.md"
    return 0
}

ensure_header() {
    [[ -f "$LOG_FILE" ]] && return 0
    {
        printf '# Run Log — %s\n\n' "$(basename "$FEATURE_DIR")"
        printf '> 由 `.specify/scripts/bash/run-log.sh` 追加,记录工作流实际运转轨迹(时间线自上而下)。\n'
        printf '>\n'
        printf '> - **GATE 行 = 机械证据**:门脚本退出码自记,模型无法篡改。\n'
        printf '> - **PHASE 块**:标 _(自述)_ 的项是编排层声明,**不构成验收证据**;\n'
        printf '>   标 _(机械核验)_ 的产物存在性由脚本核验文件系统得出。\n\n'
        printf -- '---\n\n'
    } >> "$LOG_FILE"
}

cmd_gate() {
    [[ -n "${RUN_LOG_SUPPRESS:-}" ]] && exit 0
    local name="${1:-unknown-gate}" code="${2:-?}"
    resolve_log_file || exit 0   # never break a gate over logging
    ensure_header
    local status
    if [[ "$code" == "0" ]]; then
        status="PASS"
    else
        status="FAIL (exit $code)"
    fi
    printf -- '- `%s` · **GATE** `%s` → %s  _(机械证据)_\n' "$(ts)" "$name" "$status" >> "$LOG_FILE"
}

verify_artifacts() {
    # Renders one bullet per artifact with a machine existence check.
    local csv="$1" item target
    local IFS=','
    for item in $csv; do
        item="${item#"${item%%[![:space:]]*}"}"   # ltrim
        item="${item%"${item##*[![:space:]]}"}"    # rtrim
        [[ -z "$item" ]] && continue
        if [[ "$item" = /* ]]; then target="$item"; else target="$FEATURE_DIR/$item"; fi
        if [[ -f "$target" ]]; then
            printf '  - ✓ `%s` (文件存在)\n' "$item" >> "$LOG_FILE"
        elif [[ -d "$target" && -n "$(ls -A "$target" 2>/dev/null)" ]]; then
            printf '  - ✓ `%s` (目录非空)\n' "$item" >> "$LOG_FILE"
        elif [[ -d "$target" ]]; then
            printf '  - ✗ `%s` (目录存在但为空)\n' "$item" >> "$LOG_FILE"
        else
            printf '  - ✗ `%s` (缺失)\n' "$item" >> "$LOG_FILE"
        fi
    done
}

cmd_phase() {
    local phase="" model="" skills="" scripts="" artifacts="" note=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --phase)     phase="${2:-}"; shift 2 ;;
            --model)     model="${2:-}"; shift 2 ;;
            --skills)    skills="${2:-}"; shift 2 ;;
            --scripts)   scripts="${2:-}"; shift 2 ;;
            --artifacts) artifacts="${2:-}"; shift 2 ;;
            --note)      note="${2:-}"; shift 2 ;;
            *) echo "run-log.sh phase: 未知参数 '$1'" >&2; shift ;;
        esac
    done
    if [[ -z "$phase" ]]; then
        echo "run-log.sh phase: ERROR --phase 必填" >&2
        exit 2
    fi
    if ! resolve_log_file; then
        echo "run-log.sh phase: ERROR 无法解析特性目录(检查 .specify/feature.json),日志未写入。" >&2
        exit 2
    fi
    ensure_header
    {
        printf '\n## `%s` · PHASE: %s\n\n' "$(ts)" "$phase"
        printf -- '- 模型 _(自述)_: %s\n' "${model:-—}"
        printf -- '- 激活 skill/维度 _(自述)_: %s\n' "${skills:-—}"
        printf -- '- 执行脚本 _(自述)_: %s\n' "${scripts:-—}"
    } >> "$LOG_FILE"
    if [[ -n "$artifacts" ]]; then
        printf -- '- 产物 _(机械核验)_:\n' >> "$LOG_FILE"
        verify_artifacts "$artifacts"
    else
        printf -- '- 产物 _(机械核验)_: —\n' >> "$LOG_FILE"
    fi
    printf -- '- 备注 _(自述)_: %s\n' "${note:-—}" >> "$LOG_FILE"
    echo "RUN-LOG: 已追加 PHASE($phase) → $LOG_FILE"
}

main() {
    local sub="${1:-}"
    case "$sub" in
        gate)  shift; cmd_gate "$@" ;;
        phase) shift; cmd_phase "$@" ;;
        *)
            echo "用法: run-log.sh {gate <name> <exit-code> | phase --phase NAME [--model M] [--skills CSV] [--scripts CSV] [--artifacts CSV] [--note TEXT]}" >&2
            exit 2
            ;;
    esac
}

main "$@"
