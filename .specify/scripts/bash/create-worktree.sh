#!/usr/bin/env bash
# Scaffold layered specs: module → charter → spec dimension → plan → task set.
#
# Usage:
#   create-worktree.sh module <slug> [--title "Name"]
#   create-worktree.sh charter --module <slug> <charter-slug> [--title "Name"]
#   create-worktree.sh spec-dimension --module <m> --charter <c> --dimension data
#   create-worktree.sh plan --module <m> --charter <c> [--dimension functional] --slug mvp-v1
#   create-worktree.sh task-set --module <m> --charter <c> [--dimension functional] [--plan default] --slug backend

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
TEMPLATES="$REPO_ROOT/.specify/templates"

substitute() {
    local file="$1"
    shift
    local content
    content=$(cat "$file")
    while [[ $# -ge 2 ]]; do
        local key="$1" val="$2"
        content="${content//${key}/${val}}"
        shift 2
    done
    printf '%s' "$content"
}

write_feature_json_v3() {
    local module="$1" charter="$2" dim="$3" plan="$4" task="$5"
    local spec_dim_dir="specs/$module/charters/$charter/specs/$dim"
    local work_root="specs/$module/charters/$charter/specs/$dim/plans/$plan/tasks/$task"
    local fj="$REPO_ROOT/.specify/feature.json"
    if has_jq; then
        jq -n \
            --arg v "3" \
            --arg module "$module" \
            --arg charter "$charter" \
            --arg dim "$dim" \
            --arg plan "$plan" \
            --arg task "$task" \
            --arg wr "$work_root" \
            --arg fd "$spec_dim_dir" \
            '{version: ($v|tonumber), module: $module, charter: $charter, spec_dimension: $dim, plan: $plan, task_set: $task, work_root: $wr, feature_directory: $fd}' \
            >"$fj"
    else
        cat >"$fj" <<EOF
{
  "version": 3,
  "module": "$module",
  "charter": "$charter",
  "spec_dimension": "$dim",
  "plan": "$plan",
  "task_set": "$task",
  "work_root": "$work_root",
  "feature_directory": "$spec_dim_dir"
}
EOF
    fi
}

cmd_module() {
    local slug="" title=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title) title="$2"; shift 2 ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) slug="$1"; shift ;;
        esac
    done
    [[ -n "$slug" ]] || { echo "Usage: create-worktree.sh module <slug> [--title Name]" >&2; exit 1; }
    title="${title:-$slug}"
    local mod_dir="$REPO_ROOT/specs/$slug"
    [[ ! -d "$mod_dir" ]] || { echo "Module exists: $mod_dir" >&2; exit 1; }
    mkdir -p "$mod_dir/shared"
    substitute "$TEMPLATES/module-template.yml" "MODULE_SLUG" "$slug" "MODULE_TITLE" "$title" >"$mod_dir/module.yml"
    substitute "$TEMPLATES/module-readme-template.md" "MODULE_SLUG" "$slug" "MODULE_TITLE" "$title" >"$mod_dir/README.md"
    cp "$TEMPLATES/shared-readme-template.md" "$mod_dir/shared/README.md"
    mkdir -p "$mod_dir/charters"
    echo "Created module: $mod_dir"
}

cmd_charter() {
    local module="" slug="" title=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module) module="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            -*) echo "Unknown: $1" >&2; exit 1 ;;
            *) slug="$1"; shift ;;
        esac
    done
    [[ -n "$module" && -n "$slug" ]] || { echo "Usage: create-worktree.sh charter --module <m> <charter-slug>" >&2; exit 1; }
    title="${title:-$slug}"
    local cdir="$REPO_ROOT/specs/$module/charters/$slug"
    [[ -d "$REPO_ROOT/specs/$module" ]] || { echo "Module missing: specs/$module" >&2; exit 1; }
    [[ ! -d "$cdir" ]] || { echo "Charter exists: $cdir" >&2; exit 1; }
    mkdir -p "$cdir/shared" "$cdir/specs/functional/plans/default/tasks/default"
    cp "$TEMPLATES/shared-readme-template.md" "$cdir/shared/README.md"
    substitute "$TEMPLATES/charter-readme-template.md" "CHARTER_SLUG" "$slug" "CHARTER_TITLE" "$title" >"$cdir/README.md"
    if [[ -f "$TEMPLATES/charter-template.md" ]]; then cp "$TEMPLATES/charter-template.md" "$cdir/charter.md"; else echo "# Charter: $title" >"$cdir/charter.md"; fi
    [[ -f "$TEMPLATES/charter-template.yml" ]] && cp "$TEMPLATES/charter-template.yml" "$cdir/charter.yml" || true
    cp "$TEMPLATES/spec-dimension-template.yml" "$cdir/specs/functional/spec.yml"
    cp "$TEMPLATES/spec-manifest-template.yml" "$cdir/specs/functional/spec-manifest.yml"
    TEMPLATE=$(resolve_template "spec-template" "$REPO_ROOT") || true
    if [[ -n "${TEMPLATE:-}" && -f "$TEMPLATE" ]]; then cp "$TEMPLATE" "$cdir/specs/functional/spec.md"; else echo "# Spec (functional)" >"$cdir/specs/functional/spec.md"; fi
  cp "$TEMPLATES/phase-template.yml" "$cdir/specs/functional/phase.yml" 2>/dev/null || true
    cp "$TEMPLATES/spec-coverage-template.yml" "$cdir/specs/functional/spec-coverage.yml" 2>/dev/null || true
    cp "$TEMPLATES/global-prefs-template.yml" "$cdir/specs/functional/global-prefs.yml" 2>/dev/null || true
    cp "$TEMPLATES/stack-template.yml" "$cdir/specs/functional/stack.yml" 2>/dev/null || true
    TEMPLATE=$(resolve_template "plan-template" "$REPO_ROOT") || true
    if [[ -n "${TEMPLATE:-}" && -f "$TEMPLATE" ]]; then cp "$TEMPLATE" "$cdir/specs/functional/plans/default/plan.md"; else echo "# Plan: default" >"$cdir/specs/functional/plans/default/plan.md"; fi
    cp "$TEMPLATES/plan-manifest-template.yml" "$cdir/specs/functional/plans/default/plan-manifest.yml"
    TEMPLATE=$(resolve_template "tasks-template" "$REPO_ROOT") || true
    if [[ -n "${TEMPLATE:-}" && -f "$TEMPLATE" ]]; then cp "$TEMPLATE" "$cdir/specs/functional/plans/default/tasks/default/tasks.md"; else echo "# Tasks: default" >"$cdir/specs/functional/plans/default/tasks/default/tasks.md"; fi
    cp "$TEMPLATES/phase-template.yml" "$cdir/specs/functional/plans/default/tasks/default/phase.yml" 2>/dev/null || true
    if [[ -f "$TEMPLATES/drive-template.yml" ]]; then
        cp "$TEMPLATES/drive-template.yml" "$cdir/specs/functional/drive.yml"
    fi
    write_feature_json_v3 "$module" "$slug" "functional" "default" "default"
    echo "Created charter: $cdir"
}

cmd_spec_dimension() {
    local module="" charter="" dim="data"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module) module="$2"; shift 2 ;;
            --charter) charter="$2"; shift 2 ;;
            --dimension) dim="$2"; shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
        esac
    done
    local sdir="$REPO_ROOT/specs/$module/charters/$charter/specs/$dim"
    [[ ! -d "$sdir" ]] || { echo "Dimension exists: $sdir" >&2; exit 1; }
    mkdir -p "$sdir/plans/default/tasks/default"
    substitute "$TEMPLATES/spec-dimension-template.yml" "functional" "$dim" >"$sdir/spec.yml"
    cp "$TEMPLATES/spec-manifest-template.yml" "$sdir/spec-manifest.yml"
    echo "# Spec ($dim)" >"$sdir/spec.md"
    echo "Created spec dimension: $sdir"
}

cmd_plan() {
    local module="" charter="" dim="functional" slug="mvp-v1"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module) module="$2"; shift 2 ;;
            --charter) charter="$2"; shift 2 ;;
            --dimension) dim="$2"; shift 2 ;;
            --slug) slug="$2"; shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
        esac
    done
    local pdir="$REPO_ROOT/specs/$module/charters/$charter/specs/$dim/plans/$slug"
    [[ ! -d "$pdir" ]] || { echo "Plan exists: $pdir" >&2; exit 1; }
    mkdir -p "$pdir/tasks/default"
    echo "# Plan: $slug" >"$pdir/plan.md"
    cp "$TEMPLATES/plan-manifest-template.yml" "$pdir/plan-manifest.yml"
    touch "$pdir/verify.md" "$pdir/deliver.md"
    echo "Created plan: $pdir"
}

cmd_task_set() {
    local module="" charter="" dim="functional" plan="default" slug="backend"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module) module="$2"; shift 2 ;;
            --charter) charter="$2"; shift 2 ;;
            --dimension) dim="$2"; shift 2 ;;
            --plan) plan="$2"; shift 2 ;;
            --slug) slug="$2"; shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
        esac
    done
    local tdir="$REPO_ROOT/specs/$module/charters/$charter/specs/$dim/plans/$plan/tasks/$slug"
    [[ ! -d "$tdir" ]] || { echo "Task set exists: $tdir" >&2; exit 1; }
    mkdir -p "$tdir"
    echo "# Tasks: $slug" >"$tdir/tasks.md"
    cp "$TEMPLATES/phase-template.yml" "$tdir/phase.yml" 2>/dev/null || true
    write_feature_json_v3 "$module" "$charter" "$dim" "$plan" "$slug"
    echo "Created task set: $tdir"
}

SUB="${1:-}"
shift || true
case "$SUB" in
    module) cmd_module "$@" ;;
    charter) cmd_charter "$@" ;;
    spec-dimension) cmd_spec_dimension "$@" ;;
    plan) cmd_plan "$@" ;;
    task-set) cmd_task_set "$@" ;;
    ""|-h|--help)
        echo "Usage: create-worktree.sh {module|charter|spec-dimension|plan|task-set} ..."
        exit 0
        ;;
    *) echo "Unknown subcommand: $SUB" >&2; exit 1 ;;
esac
