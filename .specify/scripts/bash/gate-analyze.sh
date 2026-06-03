#!/usr/bin/env bash
# Executable gate: cross-artifact consistency before implement.
# Aggregates the machine-checkable parts of the analyze hard-checklist.
# Subjective consistency still needs Opus; this only enforces what a script can.
#
# Usage: ./gate-analyze.sh
# Exit:  0 = pass   1 = blocked   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Run-log self-record: the exit code captured here is machine truth (model cannot edit it).
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-ANALYZE: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

REGISTRY="$REPO_ROOT/.cursor/registry.yaml"
STACK_FILE="$FEATURE_DIR/stack.yml"
fail=0

# 1) No unresolved ambiguity (delegate to gate-clarify).
# RUN_LOG_SUPPRESS: delegated sub-gate calls must not be logged as standalone events.
if ! RUN_LOG_SUPPRESS=1 "$SCRIPT_DIR/gate-clarify.sh" >/dev/null 2>&1; then
    echo "GATE-ANALYZE: FAIL — spec 仍有 [NEEDS CLARIFICATION]/TODO(见 gate-clarify.sh)"
    fail=1
fi

# 2) Tech stack confirmed (delegate to gate-stack).
if ! RUN_LOG_SUPPRESS=1 "$SCRIPT_DIR/gate-stack.sh" >/dev/null 2>&1; then
    echo "GATE-ANALYZE: FAIL — 技术栈未确认(见 gate-stack.sh)"
    fail=1
fi

# 3) Every user-story ID in spec is referenced in tasks.md (功能不漏).
if [[ -f "$FEATURE_SPEC" && -f "$TASKS" ]]; then
    story_ids=$(grep -noE '(US[0-9]+|User Story [0-9]+|用户故事[0-9]+|故事[0-9]+)' "$FEATURE_SPEC" 2>/dev/null \
        | sed -E 's/.*:(US[0-9]+|User Story [0-9]+|用户故事[0-9]+|故事[0-9]+)/\1/' \
        | sed -E 's/User Story /US/; s/用户故事/US/; s/故事/US/' | sort -u)
    if [[ -n "$story_ids" ]]; then
        while IFS= read -r sid; do
            [[ -z "$sid" ]] && continue
            num=$(echo "$sid" | grep -oE '[0-9]+')
            if ! grep -qE "(US0*${num}\b|Story 0*${num}\b|故事 ?0*${num}\b)" "$TASKS" 2>/dev/null; then
                echo "GATE-ANALYZE: FAIL — 用户故事 $sid 在 tasks.md 无对应任务落点"
                fail=1
            fi
        done <<< "$story_ids"
    fi
fi

# 4) Activated conditional dimensions all resolve to an existing skill file.
if [[ -f "$STACK_FILE" && -f "$REGISTRY" ]] && command -v ruby >/dev/null 2>&1; then
    activated=$("$SCRIPT_DIR/activate-dimensions.sh" 2>/dev/null || true)
    if [[ -n "$activated" ]]; then
        while IFS= read -r dim; do
            [[ -z "$dim" ]] && continue
            p=$(REGISTRY="$REGISTRY" DIM="$dim" ruby -ryaml -e \
                'd=YAML.load_file(ENV["REGISTRY"])["dimensions"][ENV["DIM"]]||{}; puts d["path"].to_s' 2>/dev/null)
            if [[ -n "$p" ]]; then
                p="$(resolve_registry_path "$p")" || p=""
            fi
            if [[ -z "$p" || ! -f "$p" ]]; then
                echo "GATE-ANALYZE: FAIL — 激活维度 $dim 的 skill 路径不可解析: ${p:-<empty>}"
                fail=1
            fi
        done <<< "$activated"
    fi
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-ANALYZE: PASS — 机械可判定项全过(主观一致性仍需 Opus 复核)"
    exit 0
fi
echo "GATE-ANALYZE: BLOCKED — 修复上述项后重跑" >&2
exit 1
