#!/usr/bin/env bash
# Executable gate: the release backbone (repo-level, user-triggered).
# release = "promote to production", lower cadence than MR, may AGGREGATE several already
# delivered features. Operates on a repo-level release dir, NOT a single feature dir.
# Runs the commands declared in <release-dir>/release.yml and trusts their EXIT CODES, then
# verifies: every included feature was delivered, a rollback path exists, artifact SHA, and a
# release.md with no placeholders; tier-conditional canary/SLI + expand-contract. See
# .specify/memory/release-profiles.md.
#
# Release dir resolution (first hit wins):
#   1. $1 (path, absolute or relative to repo root)
#   2. $RELEASE_DIR env
#   3. $REPO_ROOT/.releases/$(cat $REPO_ROOT/.releases/CURRENT)
#
# Usage: ./gate-release.sh [release-dir]    (RELEASE_FULL=1 also runs optional commands)
# Exit:  0 = pass   1 = release gate failed   2 = setup error

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)" || { echo "GATE-RELEASE: ERROR resolving repo root" >&2; exit 2; }

# Resolve the release dir.
RELEASE_DIR="${1:-${RELEASE_DIR:-}}"
if [[ -z "$RELEASE_DIR" ]]; then
    if [[ -f "$REPO_ROOT/.releases/CURRENT" ]]; then
        _ver="$(tr -d '[:space:]' < "$REPO_ROOT/.releases/CURRENT")"
        RELEASE_DIR="$REPO_ROOT/.releases/$_ver"
    fi
fi
if [[ -z "$RELEASE_DIR" ]]; then
    echo "GATE-RELEASE: ERROR 未指定发布目录。传入路径,或设 RELEASE_DIR,或写 .releases/CURRENT。" >&2
    exit 2
fi
[[ "$RELEASE_DIR" != /* ]] && RELEASE_DIR="$REPO_ROOT/$RELEASE_DIR"

# Run-log self-record into the release dir's run-log.md (reuse run-log via SPECIFY_FEATURE_DIRECTORY).
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
trap '_rc=$?; SPECIFY_FEATURE_DIRECTORY="$RELEASE_DIR" "$SCRIPT_DIR/run-log.sh" gate "$GATE_NAME" "$_rc" >/dev/null 2>&1 || true' EXIT

RELEASE_FILE="$RELEASE_DIR/release.yml"
RELEASE_MD="$RELEASE_DIR/release.md"

if [[ ! -d "$RELEASE_DIR" ]]; then
    echo "GATE-RELEASE: ERROR 发布目录不存在: $RELEASE_DIR" >&2
    exit 2
fi
if [[ ! -f "$RELEASE_FILE" ]]; then
    echo "GATE-RELEASE: ERROR 未找到 $RELEASE_FILE(见 .specify/templates/release-template.yml)" >&2
    exit 2
fi
command -v ruby >/dev/null 2>&1 || { echo "GATE-RELEASE: ERROR requires 'ruby'" >&2; exit 2; }

TIER=$(RELEASE_FILE="$RELEASE_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["RELEASE_FILE"])||{}; puts (d["tier"]||"").to_s' 2>/dev/null)
TIER="${TIER:-unknown}"
echo "GATE-RELEASE: 发布目录 = $RELEASE_DIR"
echo "GATE-RELEASE: DoD 档位 = $TIER (repo-level; 详见 release-profiles.md)"

fail=0

# 1) Hard precondition: every included feature must have been delivered (deliver.md present).
includes=$(RELEASE_FILE="$RELEASE_FILE" ruby -ryaml -e '
d=YAML.load_file(ENV["RELEASE_FILE"])||{}
(d["includes"]||[]).each { |x| s=x.to_s.strip; puts s unless s.empty? }' 2>/dev/null)
if [[ -z "$includes" ]]; then
    echo "GATE-RELEASE: FAIL — release.yml 的 includes 为空(上线必须聚合至少一个已 deliver 的 feature)"
    fail=1
else
    while IFS= read -r feat; do
        [[ -z "$feat" ]] && continue
        dmd="$REPO_ROOT/specs/$feat/deliver.md"
        if [[ -f "$dmd" ]]; then
            echo "GATE-RELEASE: ✓ feature 已交付: $feat"
        else
            echo "GATE-RELEASE: FAIL — feature 未交付(缺 specs/$feat/deliver.md): $feat → 先过 gate-deliver"
            fail=1
        fi
    done <<< "$includes"
fi

# 2) Run declared commands; exit code is truth. optional only with RELEASE_FULL=1.
RELEASE_FULL="${RELEASE_FULL:-0}"
cmds=$(RELEASE_FILE="$RELEASE_FILE" RELEASE_FULL="$RELEASE_FULL" ruby -ryaml -e '
d=YAML.load_file(ENV["RELEASE_FILE"])||{}
full=ENV["RELEASE_FULL"]=="1"
(d["commands"]||[]).each do |c|
  next unless c.is_a?(Hash) && c["run"]
  next if c["optional"] && !full
  puts "#{c["name"]||"cmd"}\t#{c["run"]}"
end' 2>/dev/null)

if [[ -z "$cmds" ]]; then
    echo "GATE-RELEASE: FAIL — release.yml 未声明任何 commands(至少需 preflight/deploy-prod/healthcheck)"
    fail=1
else
    while IFS=$'\t' read -r cname crun; do
        [[ -z "$crun" ]] && continue
        echo "  ▶ [$cname] $crun"
        if ( cd "$REPO_ROOT" && eval "$crun" ) >/tmp/gate-release-$$.log 2>&1; then
            echo "    ✓ [$cname] exit 0"
        else
            rc=$?
            echo "    ✗ [$cname] exit $rc"
            sed 's/^/      /' /tmp/gate-release-$$.log | tail -n 20
            fail=1
        fi
        rm -f /tmp/gate-release-$$.log
    done <<< "$cmds"
fi

# 3) Rollback path must exist (red-line「可回滚」). command (executable) OR pointer.
read -r rb_cmd rb_ptr sha_req mig_ec < <(RELEASE_FILE="$RELEASE_FILE" ruby -ryaml -e '
d=YAML.load_file(ENV["RELEASE_FILE"])||{}
rb=d["rollback"]||{}; art=d["artifact"]||{}; mig=d["migration"]||{}
puts [
  (rb.is_a?(Hash) ? (rb["command"]||"") : "").to_s.empty? ? "-" : "yes",
  (rb.is_a?(Hash) ? (rb["pointer"]||"") : "").to_s.empty? ? "-" : "yes",
  (art.is_a?(Hash) && art["sha_required"]) ? "yes" : "-",
  (mig.is_a?(Hash) && mig["expand_contract"]) ? "yes" : "-"
].join(" ")' 2>/dev/null)

if [[ "$rb_cmd" != "yes" && "$rb_ptr" != "yes" ]]; then
    echo "GATE-RELEASE: FAIL — rollback 缺失(rollback.command 或 rollback.pointer 至少一个)。红线:可回滚。"
    fail=1
else
    rb_run=$(RELEASE_FILE="$RELEASE_FILE" ruby -ryaml -e 'd=YAML.load_file(ENV["RELEASE_FILE"])||{}; rb=d["rollback"]||{}; puts (rb.is_a?(Hash) ? (rb["command"]||"") : "").to_s' 2>/dev/null)
    rb_script=$(printf '%s\n' "$rb_run" | grep -oE '[A-Za-z0-9_./-]+\.(sh|bash)' | head -n1 || true)
    if [[ -n "$rb_script" ]]; then
        [[ "$rb_script" = /* ]] && rb_target="$rb_script" || rb_target="$REPO_ROOT/$rb_script"
        if [[ ! -f "$rb_target" ]]; then
            echo "GATE-RELEASE: FAIL — rollback 脚本不存在: $rb_script"
            fail=1
        else
            echo "GATE-RELEASE: ✓ rollback 路径存在 ($rb_script)"
        fi
    else
        echo "GATE-RELEASE: ✓ rollback 路径已声明"
    fi
fi

# 4) release.md evidence: exists, no placeholders, has git_sha when sha_required.
if [[ ! -f "$RELEASE_MD" ]]; then
    echo "GATE-RELEASE: FAIL — 缺少 $RELEASE_MD(上线证据:制品SHA/健康检查/回滚指针/部署标记)"
    fail=1
else
    if grep -qE '待[[:space:]]*发|待[[:space:]]*验|待部署|待回滚|待上线|TBD' "$RELEASE_MD"; then
        echo "GATE-RELEASE: FAIL — release.md 仍有未完成占位(不得含「待发/待验/待部署/待上线/TBD」):"
        grep -nE '待[[:space:]]*发|待[[:space:]]*验|待部署|待回滚|待上线|TBD' "$RELEASE_MD" | sed 's/^/    /' | head -n 15
        fail=1
    else
        echo "GATE-RELEASE: ✓ release.md 无未完成占位"
    fi
    if [[ "$sha_req" == "yes" ]]; then
        if grep -qiE 'git[_ ]?sha|commit|[0-9a-f]{7,40}' "$RELEASE_MD"; then
            echo "GATE-RELEASE: ✓ release.md 含制品 SHA(可追溯)"
        else
            echo "GATE-RELEASE: FAIL — artifact.sha_required 但 release.md 未记录 git_sha/commit"
            fail=1
        fi
    fi
fi

# 5) Tier-conditional: T2+ needs canary/SLI evidence.
case "$TIER" in
    T2|T3)
        if [[ -f "$RELEASE_MD" ]] && grep -qiE 'canary|SLI|金丝雀' "$RELEASE_MD"; then
            echo "GATE-RELEASE: ✓ T2+ canary/SLI 证据在位"
        else
            echo "GATE-RELEASE: FAIL — $TIER 需 canary+SLI 闸证据(release.md 未见 canary/SLI)"
            fail=1
        fi
        ;;
esac

# 6) expand-contract migration evidence when declared.
if [[ "$mig_ec" == "yes" ]]; then
    if [[ -f "$RELEASE_MD" ]] && grep -qiE 'contract|收缩阶段' "$RELEASE_MD"; then
        echo "GATE-RELEASE: ✓ expand-contract 的 contract 阶段已记录"
    else
        echo "GATE-RELEASE: FAIL — migration.expand_contract 但 release.md 未记录 contract(清旧)阶段与回滚"
        fail=1
    fi
fi

if [[ "$fail" -eq 0 ]]; then
    echo "GATE-RELEASE: PASS — 交付前置/命令/回滚/证据/分档检查全过 (tier=$TIER)"
    exit 0
fi
echo "GATE-RELEASE: BLOCKED — 修复后重跑 release(上线失败回 release 修;若功能 bug 回 implement→verify→deliver)" >&2
exit 1
