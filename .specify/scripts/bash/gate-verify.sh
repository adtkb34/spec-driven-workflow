#!/usr/bin/env bash
# Executable gate: the verify backbone.
# Runs the commands declared in FEATURE_DIR/verify.yml and trusts their EXIT CODES,
# scans declared source paths for residue (stub/placeholder), and reports the DoD
# profile selected by product form. "Done" must survive this — not a self-report.
#
# verify.yml schema (in FEATURE_DIR):
#   form: web|cli|service|library|pipeline   # optional; falls back to stack.yml
#   commands:
#     - name: build
#       run: "npm run build"
#     - name: test
#       run: "npm test"
#   scan_paths: ["src"]      # optional; dirs to scan for residue (default: none)
#
# Usage: ./gate-verify.sh
# Exit:  0 = pass   1 = verify failed   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Run-log self-record: the exit code captured here is machine truth (model cannot edit it).
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-VERIFY: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

VERIFY_FILE="$FEATURE_DIR/verify.yml"
STACK_FILE="$FEATURE_DIR/stack.yml"

if [[ ! -f "$VERIFY_FILE" ]]; then
    echo "GATE-VERIFY: ERROR 未找到 $VERIFY_FILE" >&2
    echo "  在特性目录创建 verify.yml,声明 form + 启动/测试命令(见 .specify/memory/verify-profiles.md)。" >&2
    exit 2
fi
command -v ruby >/dev/null 2>&1 || { echo "GATE-VERIFY: ERROR requires 'ruby'" >&2; exit 2; }

# Resolve product form (verify.yml wins, else stack.yml, else 'unknown').
FORM=$(VERIFY_FILE="$VERIFY_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["VERIFY_FILE"])||{}; puts (d["form"]||"").to_s' 2>/dev/null)
if [[ -z "$FORM" && -f "$STACK_FILE" ]]; then
    FORM=$(STACK_FILE="$STACK_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["STACK_FILE"])||{}; puts (d["form"]||"").to_s' 2>/dev/null)
fi
FORM="${FORM:-unknown}"
echo "GATE-VERIFY: DoD 档位 = $FORM (详见 .specify/memory/verify-profiles.md)"

fail=0

# 1) Run declared commands; exit code is truth.
cmds=$(VERIFY_FILE="$VERIFY_FILE" ruby -ryaml -e '
d=YAML.load_file(ENV["VERIFY_FILE"])||{}
(d["commands"]||[]).each { |c| next unless c.is_a?(Hash) && c["run"]; puts "#{c["name"]||"cmd"}\t#{c["run"]}" }' 2>/dev/null)

if [[ -z "$cmds" ]]; then
    echo "GATE-VERIFY: FAIL — verify.yml 未声明任何 commands(至少需启动/测试命令)"
    fail=1
else
    while IFS=$'\t' read -r cname crun; do
        [[ -z "$crun" ]] && continue
        echo "  ▶ [$cname] $crun"
        if ( cd "$REPO_ROOT" && eval "$crun" ) >/tmp/gate-verify-$$.log 2>&1; then
            echo "    ✓ [$cname] exit 0"
        else
            rc=$?
            echo "    ✗ [$cname] exit $rc"
            sed 's/^/      /' /tmp/gate-verify-$$.log | tail -n 20
            fail=1
        fi
        rm -f /tmp/gate-verify-$$.log
    done <<< "$cmds"
fi

# 2) Residue scan over declared scan_paths only (avoid self/false matches).
scan_paths=$(VERIFY_FILE="$VERIFY_FILE" ruby -ryaml -e '
d=YAML.load_file(ENV["VERIFY_FILE"])||{}
(d["scan_paths"]||[]).each { |p| puts p }' 2>/dev/null)

if [[ -n "$scan_paths" ]]; then
    # Build pattern from fragments so this script does not match itself.
    residue_pat="$(printf 'TO''DO|FIX''ME|\\bstub\\b|raise NotImplemented|placeholder implementation')"
    while IFS= read -r sp; do
        [[ -z "$sp" ]] && continue
        if [[ "$sp" = /* ]]; then target="$sp"; else target="$REPO_ROOT/$sp"; fi
        [[ -e "$target" ]] || continue
        if grep -rnE "$residue_pat" "$target" >/dev/null 2>&1; then
            echo "GATE-VERIFY: FAIL — 残留实现痕迹 in $sp:"
            grep -rnE "$residue_pat" "$target" | sed 's/^/    /' | head -n 20
            fail=1
        fi
    done <<< "$scan_paths"
else
    echo "GATE-VERIFY: NOTE — verify.yml 未声明 scan_paths,跳过残留扫描(建议声明 src 目录)"
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-VERIFY: PASS — 声明命令全过、无残留;请按 $FORM 档位补齐人工验收项并写入 verify.md"
    exit 0
fi
echo "GATE-VERIFY: BLOCKED — 回 implement 修复后重跑 verify" >&2
exit 1
