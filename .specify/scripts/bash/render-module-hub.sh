#!/usr/bin/env bash
# Generate specs/<module>/index.html with module/charter/shared + 4-level navigation.
#
# Usage: render-module-hub.sh [--module SLUG]
# Exit:  0 on success; 2 on error

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
MODULE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --module) MODULE="$2"; shift 2 ;;
        -h|--help) echo "Usage: render-module-hub.sh [--module SLUG]"; exit 0 ;;
        *) echo "Unknown: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$MODULE" ]]; then
    MODULE=$(read_feature_json_field "$REPO_ROOT" "module")
    [[ -n "$MODULE" ]] || MODULE=$(basename "$(read_feature_json_feature_directory "$REPO_ROOT" 2>/dev/null || true)" 2>/dev/null || true)
fi

MOD_DIR="$REPO_ROOT/specs/$MODULE"
[[ -d "$MOD_DIR" ]] || { echo "Module dir not found: $MOD_DIR" >&2; exit 2; }

OUT="$MOD_DIR/index.html"
TITLE="$MODULE"
[[ -f "$MOD_DIR/module.yml" ]] && command -v ruby >/dev/null 2>&1 && \
    TITLE=$(ruby -ryaml -e "d=YAML.load_file('$MOD_DIR/module.yml')||{}; print d['title']||'$MODULE'" 2>/dev/null || echo "$MODULE")

{
    echo '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8"><title>'"$TITLE"'</title>'
    echo '<style>body{font-family:system-ui,sans-serif;margin:0;display:flex;min-height:100vh}'
    echo 'nav{width:280px;background:#1e1e2e;color:#cdd6f4;padding:1rem;overflow:auto}'
    echo 'nav a{color:#89b4fa;text-decoration:none;display:block;padding:.2rem 0}'
    echo 'nav .muted{color:#6c7086;font-size:.85rem;margin-top:1rem}'
    echo 'main{flex:1;padding:1.5rem}iframe{border:0;width:100%;height:calc(100vh - 3rem)}</style></head><body><nav>'
    echo "<strong>$TITLE</strong>"
    echo '<div class="muted">Module shared</div>'
    if [[ -d "$MOD_DIR/shared" ]]; then
        find "$MOD_DIR/shared" -name '*.md' | sort | while read -r f; do
            rel="${f#"$MOD_DIR/"}"
            echo "<a href=\"$rel\" target=\"frame\">$rel</a>"
        done
    fi
    echo '<div class="muted">Charters</div>'
    for cdir in "$MOD_DIR/charters"/*; do
        [[ -d "$cdir" ]] || continue
        cslug=$(basename "$cdir")
        echo "<a href=\"charters/$cslug/README.md\" target=\"frame\">charter: $cslug</a>"
        if [[ -d "$cdir/shared" ]]; then
            find "$cdir/shared" -name '*.md' | sort | while read -r f; do
                rel="${f#"$MOD_DIR/"}"
                echo "<a href=\"$rel\" target=\"frame\" style=\"padding-left:1rem\">$rel</a>"
            done
        fi
        for sdir in "$cdir/specs"/*; do
            [[ -d "$sdir" ]] || continue
            dim=$(basename "$sdir")
            echo "<a href=\"charters/$cslug/specs/$dim/spec.md\" target=\"frame\" style=\"padding-left:1rem\">spec: $dim</a>"
            for pdir in "$sdir/plans"/*; do
                [[ -d "$pdir" ]] || continue
                plan=$(basename "$pdir")
                echo "<a href=\"charters/$cslug/specs/$dim/plans/$plan/plan.md\" target=\"frame\" style=\"padding-left:1.5rem\">plan: $plan</a>"
                for tdir in "$pdir/tasks"/*; do
                    [[ -d "$tdir" ]] || continue
                    task=$(basename "$tdir")
                    echo "<a href=\"charters/$cslug/specs/$dim/plans/$plan/tasks/$task/tasks.md\" target=\"frame\" style=\"padding-left:2rem\">task: $task</a>"
                done
            done
        done
    done
    echo '</nav><main><iframe name="frame" src="README.md"></iframe></main></body></html>'
} >"$OUT"

echo "Wrote $OUT"
