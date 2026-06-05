#!/usr/bin/env bash
# Migrate flat specs/NNN-name/ to layered specs/<module>/charters/main/specs/functional/...
#
# Usage: migrate-specs-layout.sh [--source DIR] [--module-slug SLUG] [--dry-run]
# Default source: read from .specify/feature.json feature_directory or specs/001-*

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
SOURCE=""
MODULE_SLUG=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source) SOURCE="$2"; shift 2 ;;
        --module-slug) MODULE_SLUG="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: migrate-specs-layout.sh [--source DIR] [--module-slug SLUG] [--dry-run]"
            exit 0
            ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$SOURCE" ]]; then
    SOURCE=$(read_feature_json_feature_directory "$REPO_ROOT")
    [[ -n "$SOURCE" ]] || SOURCE="$REPO_ROOT/specs/001-production-scheduling"
    [[ "$SOURCE" != /* ]] && SOURCE="$REPO_ROOT/$SOURCE"
fi

[[ -d "$SOURCE" ]] || { echo "Source not found: $SOURCE" >&2; exit 1; }

if [[ -z "$MODULE_SLUG" ]]; then
    base=$(basename "$SOURCE")
    MODULE_SLUG=$(echo "$base" | sed -E 's/^[0-9]+-//')
    [[ -z "$MODULE_SLUG" ]] && MODULE_SLUG="$base"
fi

TARGET="$REPO_ROOT/specs/$MODULE_SLUG/charters/main/specs/functional"
if [[ -d "$TARGET/spec.md" || -f "$TARGET/spec.md" ]]; then
    echo "Already migrated (spec.md exists): $TARGET" >&2
    exit 0
fi

run() {
    if $DRY_RUN; then echo "[dry-run] $*"; else "$@"; fi
}

echo "Migrating: $SOURCE -> specs/$MODULE_SLUG/charters/main/..."

run "$SCRIPT_DIR/create-worktree.sh" module "$MODULE_SLUG" --title "$MODULE_SLUG" 2>/dev/null || true
run mkdir -p "$REPO_ROOT/specs/$MODULE_SLUG/charters/main/shared"
run "$SCRIPT_DIR/create-worktree.sh" charter --module "$MODULE_SLUG" main --title "Main" 2>/dev/null || true

SPEC_DIM="$REPO_ROOT/specs/$MODULE_SLUG/charters/main/specs/functional"
run mkdir -p "$SPEC_DIM/docs" "$SPEC_DIM/plans/default/tasks/default"

if [[ -f "$SOURCE/spec.md" ]]; then
    run cp "$SOURCE/spec.md" "$SPEC_DIM/docs/legacy-spec-body.md"
    run cp "$REPO_ROOT/.specify/templates/spec-manifest-template.yml" "$SPEC_DIM/spec-manifest.yml"
    if command -v ruby >/dev/null 2>&1; then
        run ruby -ryaml -e "
          m = YAML.load_file('$SPEC_DIM/spec-manifest.yml') || {}
          m['shards'] = {'legacy_body' => 'docs/legacy-spec-body.md'}
          File.write('$SPEC_DIM/spec-manifest.yml', m.to_yaml)
        "
    fi
    if [[ -f "$REPO_ROOT/.specify/templates/spec-template.md" ]]; then
        run cp "$REPO_ROOT/.specify/templates/spec-template.md" "$SPEC_DIM/spec.md"
    else
        echo "# Spec index (see legacy body)" >"$SPEC_DIM/spec.md"
    fi
fi

for f in stack.yml global-prefs.yml spec-coverage.yml phase.yml charter.md charter.yml drive.yml; do
    [[ -f "$SOURCE/$f" ]] && run cp "$SOURCE/$f" "$SPEC_DIM/$f" 2>/dev/null || \
        ([[ "$f" == charter.* ]] && run cp "$SOURCE/$f" "$REPO_ROOT/specs/$MODULE_SLUG/charters/main/$f" 2>/dev/null) || true
done
[[ -f "$SOURCE/charter.md" ]] && run cp "$SOURCE/charter.md" "$REPO_ROOT/specs/$MODULE_SLUG/charters/main/charter.md"

PLAN_DIR="$SPEC_DIM/plans/default"
run mkdir -p "$PLAN_DIR/tasks/default"
[[ -f "$SOURCE/plan.md" ]] && run cp "$SOURCE/plan.md" "$PLAN_DIR/plan.md"
[[ -f "$SOURCE/tasks.md" ]] && run cp "$SOURCE/tasks.md" "$PLAN_DIR/tasks/default/tasks.md"
[[ -f "$SOURCE/verify.md" ]] && run cp "$SOURCE/verify.md" "$PLAN_DIR/verify.md"
[[ -f "$SOURCE/deliver.md" ]] && run cp "$SOURCE/deliver.md" "$PLAN_DIR/deliver.md"

if ! $DRY_RUN; then
    if has_jq; then
        jq -n \
            --arg module "$MODULE_SLUG" \
            --arg fd "specs/$MODULE_SLUG/charters/main/specs/functional" \
            --arg wr "specs/$MODULE_SLUG/charters/main/specs/functional/plans/default/tasks/default" \
            '{version: 3, module: $module, charter: "main", spec_dimension: "functional", plan: "default", task_set: "default", work_root: $wr, feature_directory: $fd}' \
            >"$REPO_ROOT/.specify/feature.json"
    else
        cat >"$REPO_ROOT/.specify/feature.json" <<EOF
{
  "version": 3,
  "module": "$MODULE_SLUG",
  "charter": "main",
  "spec_dimension": "functional",
  "plan": "default",
  "task_set": "default",
  "work_root": "specs/$MODULE_SLUG/charters/main/specs/functional/plans/default/tasks/default",
  "feature_directory": "specs/$MODULE_SLUG/charters/main/specs/functional"
}
EOF
    fi
fi

echo "Done. New spec dimension: $SPEC_DIM"
echo "Legacy body: $SPEC_DIM/docs/legacy-spec-body.md"
