#!/usr/bin/env bash
# Executable gate: the deliver backbone (per-feature).
# deliver = "merge to main + staging", follows the MR cadence. Runs the commands declared
# in FEATURE_DIR/deliver.yml and trusts their EXIT CODES, then checks deliver.md evidence
# (PR / CI / artifact SHA; staging for T1+). Hard precondition: verify must have passed.
# See .specify/memory/release-profiles.md.
#
# deliver.yml schema (in FEATURE_DIR): see .specify/templates/deliver-template.yml
#
# Usage: ./gate-deliver.sh        (DELIVER_FULL=1 also runs optional commands)
# Exit:  0 = pass   1 = deliver gate failed   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

_paths_output=$(get_feature_paths) || { echo "GATE-DELIVER: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

DELIVER_FILE="$FEATURE_DIR/deliver.yml"
STACK_FILE="$FEATURE_DIR/stack.yml"
VERIFY_MD="$FEATURE_DIR/verify.md"
DELIVER_MD="$FEATURE_DIR/deliver.md"

if [[ ! -f "$DELIVER_FILE" ]]; then
    echo "GATE-DELIVER: ERROR 未找到 $DELIVER_FILE" >&2
    echo "  在特性目录创建 deliver.yml(见 .specify/templates/deliver-template.yml)，或用 /speckit-release 生成。" >&2
    exit 2
fi
command -v ruby >/dev/null 2>&1 || { echo "GATE-DELIVER: ERROR requires 'ruby'" >&2; exit 2; }

# Hard precondition: deliver runs AFTER verify.
if [[ ! -f "$VERIFY_MD" ]]; then
    echo "GATE-DELIVER: FAIL — 缺少 ${VERIFY_MD}。deliver 必须在 verify 通过之后(先过 gate-verify)。" >&2
    exit 1
fi

TIER=$(DELIVER_FILE="$DELIVER_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["DELIVER_FILE"])||{}; puts (d["tier"]||"").to_s' 2>/dev/null)
if [[ -z "$TIER" && -f "$STACK_FILE" ]]; then
    TIER=$(STACK_FILE="$STACK_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["STACK_FILE"])||{}; r=d["release"]||{}; puts (r.is_a?(Hash) ? (r["tier"]||"") : "").to_s' 2>/dev/null)
fi
TIER="${TIER:-unknown}"
echo "GATE-DELIVER: DoD 档位 = $TIER (per-feature; 详见 release-profiles.md)"

fail=0

# 1) Run declared commands; exit code is truth.
DELIVER_FULL="${DELIVER_FULL:-0}"
cmds=$(DELIVER_FILE="$DELIVER_FILE" DELIVER_FULL="$DELIVER_FULL" ruby -ryaml -e '
d=YAML.load_file(ENV["DELIVER_FILE"])||{}
full=ENV["DELIVER_FULL"]=="1"
(d["commands"]||[]).each do |c|
  next unless c.is_a?(Hash) && c["run"]
  next if c["optional"] && !full
  puts "#{c["name"]||"cmd"}\t#{c["run"]}"
end' 2>/dev/null)

if [[ -z "$cmds" ]]; then
    echo "GATE-DELIVER: FAIL — deliver.yml 未声明任何 commands(至少需 open-pr/ci-green/merge)"
    fail=1
else
    while IFS=$'\t' read -r cname crun; do
        [[ -z "$crun" ]] && continue
        echo "  ▶ [$cname] $crun"
        if ( cd "$REPO_ROOT" && eval "$crun" ) >/tmp/gate-deliver-$$.log 2>&1; then
            echo "    ✓ [$cname] exit 0"
        else
            rc=$?
            echo "    ✗ [$cname] exit $rc"
            sed 's/^/      /' /tmp/gate-deliver-$$.log | tail -n 20
            fail=1
        fi
        rm -f /tmp/gate-deliver-$$.log
    done <<< "$cmds"
fi

# 2) deliver.md evidence: exists, no placeholders, has SHA + PR/CI references.
if [[ ! -f "$DELIVER_MD" ]]; then
    echo "GATE-DELIVER: FAIL — 缺少 $DELIVER_MD(交付证据:PR链接/CI runID/制品 SHA;T1+ 加 staging)"
    fail=1
else
    if grep -qE '待[[:space:]]*交付|待合并|待 CI|TBD' "$DELIVER_MD"; then
        echo "GATE-DELIVER: FAIL — deliver.md 仍有未完成占位(不得含「待交付/待合并/待 CI/TBD」):"
        grep -nE '待[[:space:]]*交付|待合并|待 CI|TBD' "$DELIVER_MD" | sed 's/^/    /' | head -n 15
        fail=1
    else
        echo "GATE-DELIVER: ✓ deliver.md 无未完成占位"
    fi
    sha_req=$(DELIVER_FILE="$DELIVER_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["DELIVER_FILE"])||{}; a=d["artifact"]||{}; puts (a.is_a?(Hash)&&a["sha_required"]) ? "yes":"-"' 2>/dev/null)
    if [[ "$sha_req" == "yes" ]]; then
        if grep -qiE 'git[_ ]?sha|commit|[0-9a-f]{7,40}' "$DELIVER_MD"; then
            echo "GATE-DELIVER: ✓ deliver.md 含制品 SHA"
        else
            echo "GATE-DELIVER: FAIL — artifact.sha_required 但 deliver.md 未记录 git_sha/commit"
            fail=1
        fi
    fi
    if grep -qiE 'PR|pull request|MR|merge request|#[0-9]+' "$DELIVER_MD"; then
        echo "GATE-DELIVER: ✓ deliver.md 含 PR/MR 引用"
    else
        echo "GATE-DELIVER: FAIL — deliver.md 未见 PR/MR 引用(deliver 以 PR 为评审与状态检查边界)"
        fail=1
    fi
fi

# 3) Tier-conditional: T1+ needs staging/smoke evidence.
case "$TIER" in
    T1|T2|T3)
        if [[ -f "$DELIVER_MD" ]] && grep -qiE 'staging|smoke' "$DELIVER_MD"; then
            echo "GATE-DELIVER: ✓ T1+ staging/smoke 证据在位"
        else
            echo "GATE-DELIVER: FAIL — $TIER 需 staging+smoke 证据(deliver.md 未见 staging/smoke)"
            fail=1
        fi
        ;;
esac

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-DELIVER: PASS — 命令/证据/分档检查全过 (tier=$TIER)。可纳入某次 release 上线。"
    exit 0
fi
echo "GATE-DELIVER: BLOCKED — 修复后重跑 deliver" >&2
exit 1
