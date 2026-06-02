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
#   ./run-log.sh phase --phase plan --model "gpt-4.1" --skills "api_design,data_modeling" \
#   # --model 填本次实际模型 ID;省略时由 resolve_model_for_log 推断(勿填 Opus/Composer 路由档名)
#                --artifacts "plan.md,research.md,contracts" --note "确认 REST + Postgres"

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# Detect IDE/runtime (best effort). Override with SPECKIT_RUNTIME=cursor|copilot|other
detect_runtime() {
    if [[ -n "${SPECKIT_RUNTIME:-}" ]]; then
        printf '%s\n' "$SPECKIT_RUNTIME"
        return
    fi
    if [[ -n "${CURSOR_TRACE_ID:-}" ]] || [[ "${CURSOR_AGENT:-}" == "1" ]]; then
        printf '%s\n' "cursor"
        return
    fi
    if [[ -n "${GITHUB_COPILOT_ENABLED:-}" ]] \
        || [[ -n "${GITHUB_COPILOT_CHAT_ENABLED:-}" ]] \
        || [[ "${GITHUB_COPILOT_CHAT_AGENT_ENABLED:-}" == "true" ]]; then
        printf '%s\n' "copilot"
        return
    fi
    printf '%s\n' "unknown"
}

# --- Auto-read model ID from local IDE/CLI config (best effort; IDE chat 未必注入 env) ---
_read_json_model_id() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$file" <<'PY' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(1)
for key in ("selectedModel", "model"):
    block = d.get(key)
    if isinstance(block, dict) and block.get("modelId"):
        print(block["modelId"])
        sys.exit(0)
m = d.get("model")
if isinstance(m, str) and m.strip():
    print(m.strip())
    sys.exit(0)
sys.exit(1)
PY
}

read_cursor_cli_config_model() {
    local f="${CURSOR_CLI_CONFIG:-$HOME/.cursor/cli-config.json}"
    _read_json_model_id "$f"
}

read_copilot_cli_config_model() {
    local f="${COPILOT_HOME:-$HOME/.copilot}/settings.json"
    _read_json_model_id "$f"
}

# VS Code / Copilot Chat: workspace or user settings.json (comments stripped crudely)
read_vscode_settings_model() {
    local f repo_root
    repo_root=$(get_repo_root 2>/dev/null) || repo_root=""
    for f in \
        "${repo_root:+$repo_root/.vscode/settings.json}" \
        "${VSCODE_SETTINGS:-$HOME/Library/Application Support/Code/User/settings.json}"; do
        [[ -n "$f" && -f "$f" ]] || continue
        command -v python3 >/dev/null 2>&1 || continue
        python3 - "$f" <<'PY' 2>/dev/null && return 0
import json, re, sys
raw = open(sys.argv[1], encoding="utf-8").read()
raw = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
raw = re.sub(r"//.*?$", "", raw, flags=re.M)
try:
    d = json.loads(raw)
except Exception:
    sys.exit(1)
for k in (
    "github.copilot.chat.selectedModel",
    "github.copilot.chat.agent.selectedModel",
    "chat.agent.defaultModel",
    "chat.model",
):
    v = d.get(k)
    if isinstance(v, str) and v.strip():
        print(v.strip())
        sys.exit(0)
sys.exit(1)
PY
    done
    return 1
}

# Resolve model name for run-log: ACTUAL model used in this session, not routing tier labels.
# Auto priority (omit --model): SPECKIT_MODEL > runtime env > IDE config files > tier fallback
resolve_model_for_log() {
    local phase="${1:-}" explicit="${2:-}"
    local runtime auto=""
    runtime=$(detect_runtime)

    if [[ -n "$explicit" ]]; then
        if [[ "$runtime" == "copilot" ]] && [[ "$explicit" =~ ^(Opus|Composer|opus|composer)$ ]]; then
            echo "RUN-LOG: WARN --model=$explicit 像是 Cursor 路由档,但当前为 Copilot;请传实际模型或设 SPECKIT_MODEL" >&2
        fi
        printf '%s\n' "$explicit"
        return
    fi

    if [[ -n "${SPECKIT_MODEL:-}" ]]; then
        printf '%s\n' "$SPECKIT_MODEL"
        return
    fi

    case "$runtime" in
        copilot)
            if [[ -n "${COPILOT_MODEL:-}" ]]; then
                printf 'Copilot/%s\n' "$COPILOT_MODEL"; return
            fi
            if auto=$(read_copilot_cli_config_model); then
                printf 'Copilot/%s _(auto:copilot-settings)_\n' "$auto"; return
            fi
            if auto=$(read_vscode_settings_model); then
                printf 'Copilot/%s _(auto:vscode-settings)_\n' "$auto"; return
            fi
            if [[ -n "${GITHUB_COPILOT_CHAT_MODEL:-}" ]]; then
                printf 'Copilot/%s\n' "$GITHUB_COPILOT_CHAT_MODEL"; return
            fi
            printf '%s\n' "Copilot-GPT (未自动识别;export SPECKIT_MODEL=或 --model)"
            ;;
        cursor)
            if [[ -n "${CURSOR_MODEL:-}" ]]; then
                printf '%s\n' "$CURSOR_MODEL"; return
            fi
            if auto=$(read_cursor_cli_config_model); then
                printf '%s _(auto:cursor-cli-config)_\n' "$auto"; return
            fi
            case "$phase" in
                implement) printf '%s\n' "Composer (未自动识别;请 --model)" ;;
                *)         printf '%s\n' "Opus (未自动识别;请 --model)" ;;
            esac
            ;;
        *)
            # Unknown runtime: try any config file
            if auto=$(read_cursor_cli_config_model); then
                printf '%s _(auto:cursor-cli-config)_\n' "$auto"; return
            fi
            if auto=$(read_copilot_cli_config_model); then
                printf 'Copilot/%s _(auto:copilot-settings)_\n' "$auto"; return
            fi
            case "$phase" in
                implement) printf '%s\n' "fast-tier" ;;
                verify|specify|clarify|plan|analyze|tasks|constitution)
                    printf '%s\n' "strong-tier" ;;
                *) printf '%s\n' "unknown" ;;
            esac
            ;;
    esac
}

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
        printf '>   标 _(机械核验)_ 的产物存在性由脚本核验文件系统得出;路径为可点击链接。\n\n'
        printf -- '---\n\n'
    } >> "$LOG_FILE"
}

# Markdown link for an artifact path (clickable in Cursor/VS Code preview).
# Relative items → ./path under FEATURE_DIR; absolute → file:// URI.
artifact_md_link() {
    local item="$1" target="$2"
    local href label="$item"

    if [[ "$item" = /* ]]; then
        if command -v python3 >/dev/null 2>&1; then
            href=$(FILE_URI_TARGET="$target" python3 -c \
                'from pathlib import Path; import os; print(Path(os.environ["FILE_URI_TARGET"]).resolve().as_uri())' \
                2>/dev/null) || href="file://$target"
        else
            href="file://$target"
        fi
    else
        href="./${item#./}"
        [[ -d "$target" ]] && href="${href%/}/"
    fi

    label="${label//]/\\]}"
    printf '[%s](%s)' "$label" "$href"
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
    # Renders one bullet per artifact with a machine existence check + clickable markdown link.
    local csv="$1" item target link
    local IFS=','
    for item in $csv; do
        item="${item#"${item%%[![:space:]]*}"}"   # ltrim
        item="${item%"${item##*[![:space:]]}"}"    # rtrim
        [[ -z "$item" ]] && continue
        if [[ "$item" = /* ]]; then target="$item"; else target="$FEATURE_DIR/$item"; fi
        link=$(artifact_md_link "$item" "$target")
        if [[ -f "$target" ]]; then
            printf '  - ✓ %s (文件存在)\n' "$link" >> "$LOG_FILE"
        elif [[ -d "$target" && -n "$(ls -A "$target" 2>/dev/null)" ]]; then
            printf '  - ✓ %s (目录非空)\n' "$link" >> "$LOG_FILE"
        elif [[ -d "$target" ]]; then
            printf '  - ✗ %s (目录存在但为空)\n' "$link" >> "$LOG_FILE"
        else
            printf '  - ✗ %s (缺失)\n' "$link" >> "$LOG_FILE"
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
    local resolved_model
    resolved_model=$(resolve_model_for_log "$phase" "$model")
    {
        printf '\n## `%s` · PHASE: %s\n\n' "$(ts)" "$phase"
        printf -- '- 模型 _(自述·实际运行)_: %s\n' "$resolved_model"
        printf -- '- 运行时 _(推断)_: %s\n' "$(detect_runtime)"
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
