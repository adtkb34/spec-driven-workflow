#!/usr/bin/env bash
# Executable gate: the verify backbone.
# Runs the commands declared in FEATURE_DIR/verify.yml and trusts their EXIT CODES,
# scans declared source paths for residue (stub/placeholder), and reports the DoD
# profile selected by product form. "Done" must survive this — not a self-report.
#
# verify.yml schema (in FEATURE_DIR):
#   form: web|desktop|cli|service|library|pipeline   # optional; falls back to stack.yml
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

# 0) 从 spec/tasks 同步 verify-coverage.yml 并合并 verify.yml（防漏测项）
if [[ -x "$SCRIPT_DIR/sync-verify.sh" ]]; then
    echo "GATE-VERIFY: 同步验收清单 (spec/tasks → verify-coverage.yml)…"
    if ! "$SCRIPT_DIR/sync-verify.sh"; then
        echo "GATE-VERIFY: WARN — sync-verify 失败，继续用现有 verify.yml" >&2
    fi
fi

# 1) Run declared commands; exit code is truth.
#    optional: true 的命令仅当 VERIFY_FULL=1 时执行（如 tauri build）。
VERIFY_FULL="${VERIFY_FULL:-0}"
cmds=$(VERIFY_FILE="$VERIFY_FILE" VERIFY_FULL="$VERIFY_FULL" ruby -ryaml -e '
d=YAML.load_file(ENV["VERIFY_FILE"])||{}
full=ENV["VERIFY_FULL"]=="1"
(d["commands"]||[]).each do |c|
  next unless c.is_a?(Hash) && c["run"]
  next if c["optional"] && !full
  puts "#{c["name"]||"cmd"}\t#{c["run"]}"
end' 2>/dev/null)

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

# 3) GUI 形态：verify.md 必须存在且不得残留「待跑/待 GUI」(gate-verify PASS ≠ 可交付)。
VERIFY_MD="$FEATURE_DIR/verify.md"
needs_gui_closure=0
case "$FORM" in
    web|desktop) needs_gui_closure=1 ;;
esac
if [[ "$needs_gui_closure" -eq 0 && -f "$STACK_FILE" ]] \
   && grep -qE '^[[:space:]]*ui:[[:space:]]*true' "$STACK_FILE"; then
    needs_gui_closure=1
fi

# 2b) verify.yml / verify.md 与 spec/tasks 覆盖对齐（verify-coverage.yml）
if [[ -x "$SCRIPT_DIR/sync-verify.sh" ]]; then
    if ! "$SCRIPT_DIR/sync-verify.sh" --check; then
        fail=1
    else
        echo "GATE-VERIFY: ✓ verify 与 spec/tasks 覆盖对齐"
    fi
fi

if [[ "$needs_gui_closure" -eq 1 ]]; then
    if [[ ! -f "$VERIFY_MD" ]]; then
        echo "GATE-VERIFY: FAIL — 缺少 $VERIFY_MD(GUI 形态必须先写验收证据)"
        fail=1
    elif grep -qE '待[[:space:]]*GUI|待跑|待 GUI' "$VERIFY_MD"; then
        echo "GATE-VERIFY: FAIL — verify.md 仍有未完成的 GUI 验收(不得含「待跑/待 GUI」):"
        grep -nE '待[[:space:]]*GUI|待跑|待 GUI' "$VERIFY_MD" | sed 's/^/    /' | head -n 15
        fail=1
    else
        echo "GATE-VERIFY: ✓ verify.md GUI 验收表无「待跑」占位"
    fi
fi

# 4) 桌面/WebView 栈：禁止 window.prompt/alert/confirm（Tauri/WKWebView 常静默失败）。
is_webview_stack=0
[[ "$FORM" == "desktop" ]] && is_webview_stack=1
if [[ -f "$STACK_FILE" ]] && grep -qiE 'tauri|electron' "$STACK_FILE"; then
    is_webview_stack=1
fi

if [[ "$is_webview_stack" -eq 1 && -n "$scan_paths" ]]; then
    webview_pat='window\.(prompt|alert|confirm)\s*\('
    while IFS= read -r sp; do
        [[ -z "$sp" ]] && continue
        if [[ "$sp" = /* ]]; then target="$sp"; else target="$REPO_ROOT/$sp"; fi
        [[ -e "$target" ]] || continue
        if grep -rnE "$webview_pat" "$target" >/dev/null 2>&1; then
            echo "GATE-VERIFY: FAIL — WebView 栈不得使用浏览器原生对话框 API:"
            grep -rnE "$webview_pat" "$target" | sed 's/^/    /' | head -n 15
            echo "    → 请改用应用内 Dialog 组件(见 verify-profiles.md · desktop 档)" >&2
            fail=1
        fi
    done <<< "$scan_paths"
    if [[ "$fail" -eq 0 ]]; then
        echo "GATE-VERIFY: ✓ 未检出 window.prompt/alert/confirm"
    fi
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-VERIFY: PASS — 命令/残留/GUI closure/WebView API 检查全过 (form=$FORM)"
    exit 0
fi
echo "GATE-VERIFY: BLOCKED — 回 implement 修复后重跑 verify" >&2
exit 1
