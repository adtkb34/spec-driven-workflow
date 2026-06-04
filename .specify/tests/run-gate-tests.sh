#!/usr/bin/env bash
# Gate regression harness — the gates are this workflow's backbone ("退出码即真相"),
# so they themselves need a test. Each case builds a synthetic FEATURE_DIR fixture,
# points the gate at it via SPECIFY_FEATURE_DIRECTORY, and asserts the exit code for
# both the PASS path and the BLOCK path. No real feature is touched.
#
# Usage: .specify/tests/run-gate-tests.sh
# Exit:  0 = all cases passed   1 = one or more cases failed   2 = setup error
#
# Note: gate-verify's full PASS path depends on sync-verify + spec/tasks coverage and
# is intentionally out of scope here (covered by real-feature dogfood); we assert only
# its deterministic ERROR(2) and BLOCK(non-zero) behaviors.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_DIR="$(CDPATH="" cd "$SCRIPT_DIR/../scripts/bash" && pwd)"

[[ -d "$BASH_DIR" ]] || { echo "SETUP ERROR: gate scripts dir not found: $BASH_DIR" >&2; exit 2; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gate-tests.XXXXXX")"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

# Logging from gates would pollute the fixture; suppress it everywhere.
export RUN_LOG_SUPPRESS=1

pass=0
fail=0
skip=0

# gate-spec-coverage and validate-workflow-index require ruby (YAML).
HAS_RUBY=0
command -v ruby >/dev/null 2>&1 && HAS_RUBY=1

expect_or_skip_ruby() {
    local label="$1" want="$2" gate="$3"
    shift 3
    if [[ "$HAS_RUBY" -eq 0 ]]; then
        printf '  \033[33mskip\033[0m %-44s (no ruby)\n' "$label"
        skip=$((skip + 1))
        return
    fi
    expect "$label" "$want" "$gate" "$@"
}

# new_fixture <name> -> echoes an absolute, empty fixture dir
new_fixture() {
    local d="$TMP_ROOT/$1"
    rm -rf "$d"; mkdir -p "$d"
    echo "$d"
}

# expect <label> <expected_exit> <gate-script> [args...]
# Uses the fixture dir set in $FIX via SPECIFY_FEATURE_DIRECTORY.
expect() {
    local label="$1" want="$2" gate="$3"; shift 3
    local got
    SPECIFY_FEATURE_DIRECTORY="$FIX" "$BASH_DIR/$gate" "$@" >/dev/null 2>&1
    got=$?
    if [[ "$got" == "$want" ]]; then
        printf '  \033[32mok\033[0m   %-44s (exit %s)\n' "$label" "$got"
        pass=$((pass + 1))
    else
        printf '  \033[31mFAIL\033[0m %-44s (want %s, got %s)\n' "$label" "$want" "$got"
        fail=$((fail + 1))
    fi
}

# Non-zero (but not setup-error 2) — used where the exact block code is 1 but we
# only care that it did NOT pass.
expect_blocked() {
    local label="$1" gate="$2"; shift 2
    local got
    SPECIFY_FEATURE_DIRECTORY="$FIX" "$BASH_DIR/$gate" "$@" >/dev/null 2>&1
    got=$?
    if [[ "$got" != "0" ]]; then
        printf '  \033[32mok\033[0m   %-44s (blocked, exit %s)\n' "$label" "$got"
        pass=$((pass + 1))
    else
        printf '  \033[31mFAIL\033[0m %-44s (expected non-zero, got 0)\n' "$label"
        fail=$((fail + 1))
    fi
}

stack_ok() {
    cat > "$FIX/stack.yml" <<'YAML'
form: web
complexity: standard
ui: false
global_prefs: ignore
confirmed: true
YAML
}

global_prefs_ok() {
    cat > "$FIX/global-prefs.yml" <<'YAML'
version: 1
decision: ignore
confirmed: true
confirmed_at: "2026-06-04T12:00:00Z"
global_prefs_allow: []
YAML
}

spec_pass_standard() {
    cat > "$FIX/spec.md" <<'SPEC'
# Feature: Gate Test

## Background & Goals

Real background for gate testing.

## Current State (As-Is)

Greenfield; no legacy system.

## Input Q&A (②③④⑤)

### ② 现状 As-Is
- **Q:** Existing system? **A:** No greenfield _(specify ping)_

### ③ 基线功能需求
- **Q:** Core scope? **A:** Basic CRUD _(specify ping)_

### ④ 候选方案
- _(none yet)_

### ⑤ 环境与技术栈
- _(none yet)_

## Assumptions
- [ASSUMPTION] Test users exist for gate harness

## User Scenarios
User completes primary flow.
SPEC
}

spec_coverage_standard() {
    cat > "$FIX/spec-coverage.yml" <<'YAML'
version: 1
ping_completed_at: "2026-06-04T12:00:00Z"
complexity: standard
dimensions:
  background:
    status: covered
  as_is:
    status: covered
  baseline:
    status: covered
  candidate:
    status: deferred_clarify
  environment:
    status: deferred_stack_gate
input_qa_count:
  "2": 1
  "3": 1
  "4": 0
  "5": 0
YAML
}

spec_pass_trivial() {
    cat > "$FIX/spec.md" <<'SPEC'
# Feature: Trivial Gate Test

## Background & Goals

Small fix for gate testing.

## Input Q&A (②③④⑤)

### ② 现状 As-Is
- **Q:** Any legacy? **A:** waived — trivial greenfield _(specify ping)_

### ③ 基线功能需求
- _(none yet)_

### ④ 候选方案
- _(none yet)_

### ⑤ 环境与技术栈
- _(none yet)_

## Assumptions
- Users can access the tool
SPEC
}

spec_coverage_with_q5() {
    cat > "$FIX/spec-coverage.yml" <<'YAML'
version: 1
ping_completed_at: "2026-06-04T12:00:00Z"
complexity: standard
dimensions:
  background:
    status: covered
  as_is:
    status: covered
  baseline:
    status: covered
  candidate:
    status: deferred_clarify
  environment:
    status: covered
input_qa_count:
  "2": 1
  "3": 1
  "4": 0
  "5": 1
YAML
}

spec_pass_with_q5() {
    cat > "$FIX/spec.md" <<'SPEC'
# Feature: Gate Test

## Background & Goals

Real background for gate testing.

## Current State (As-Is)

Greenfield; no legacy system.

## Input Q&A (②③④⑤)

### ② 现状 As-Is
- **Q:** Existing system? **A:** No greenfield _(specify ping)_

### ③ 基线功能需求
- **Q:** Core scope? **A:** Basic CRUD _(specify ping)_

### ④ 候选方案
- _(none yet)_

### ⑤ 环境与技术栈
- **Q:** Target runtime? **A:** Node 20 LTS _(stack gate)_

## Assumptions
- [ASSUMPTION] Test users exist for gate harness

## User Scenarios
User completes primary flow.
SPEC
}

spec_coverage_trivial() {
    cat > "$FIX/spec-coverage.yml" <<'YAML'
version: 1
ping_completed_at: "2026-06-04T12:00:00Z"
complexity: trivial
dimensions:
  background:
    status: covered
  as_is:
    status: waived
    note: "trivial greenfield"
  baseline:
    status: deferred_clarify
  candidate:
    status: deferred_clarify
  environment:
    status: deferred_stack_gate
input_qa_count:
  "2": 1
  "3": 0
  "4": 0
  "5": 0
YAML
}

charter_ok() {
    cat > "$FIX/charter.yml" <<'YAML'
version: 1
complexity: standard
confirmed: true
YAML
}

charter_pass_md() {
    cat > "$FIX/charter.md" <<'CHARTER'
# Feature Charter: Gate Test

## Background & Stakeholders

Planning team needs better scheduling visibility.

## As-Is Summary

Excel-based scheduling today.

## Goals & Success Criteria

Reduce planning cycle time by 30% within Q3.

## In-Scope / Out-of-Scope

**In scope:**

- Daily production scheduling for one plant

**Out of scope:**

- Multi-factory optimization

## Core Business Logic

### Main Flow

1. Import orders
2. Assign capacity
3. Publish plan

### Business Rules

- Due date takes priority over setup cost

### Conflict Priorities

- Customer A rush orders override default sequence

## Deferred to Spec / Plan

- FR and acceptance in spec.md
CHARTER
}

echo "── gate-charter ──────────────────────────────────────────"
FIX="$(new_fixture charter-pass)"
charter_ok
charter_pass_md
expect "confirmed + charter.md -> PASS" 0 gate-charter.sh

FIX="$(new_fixture charter-no-yml)"
charter_pass_md
expect "无 charter.yml -> BLOCK" 1 gate-charter.sh

FIX="$(new_fixture charter-unconfirmed)"
charter_pass_md
printf 'version: 1\ncomplexity: standard\nconfirmed: false\n' > "$FIX/charter.yml"
expect "confirmed:false -> BLOCK" 1 gate-charter.sh

FIX="$(new_fixture charter-template)"
charter_ok
cp "$BASH_DIR/../../templates/charter-template.md" "$FIX/charter.md" 2>/dev/null || true
expect "模板占位 -> BLOCK" 1 gate-charter.sh

echo "── gate-clarify ──────────────────────────────────────────"
FIX="$(new_fixture clarify-pass)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
expect_or_skip_ruby "clean spec + coverage -> PASS" 0 gate-clarify.sh

FIX="$(new_fixture clarify-block)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
printf '\nThe limit is [NEEDS CLARIFICATION: how many?].\n' >> "$FIX/spec.md"
expect "残留 NEEDS CLARIFICATION -> BLOCK" 1 gate-clarify.sh

FIX="$(new_fixture clarify-todo)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
printf '\nTODO: decide auth.\n' >> "$FIX/spec.md"
expect "残留 TODO -> BLOCK" 1 gate-clarify.sh

FIX="$(new_fixture clarify-coverage-missing)"
spec_pass_standard
global_prefs_ok
expect "占位符干净但无 coverage -> BLOCK" 1 gate-clarify.sh

echo "── gate-global-prefs ─────────────────────────────────────"
FIX="$(new_fixture gprefs-pass)"
global_prefs_ok
expect "global-prefs confirmed -> PASS" 0 gate-global-prefs.sh

FIX="$(new_fixture gprefs-unconfirmed)"
cat > "$FIX/global-prefs.yml" <<'YAML'
version: 1
decision: ignore
confirmed: false
YAML
expect "confirmed:false -> BLOCK" 1 gate-global-prefs.sh

FIX="$(new_fixture gprefs-selective-empty)"
cat > "$FIX/global-prefs.yml" <<'YAML'
version: 1
decision: selective
confirmed: true
global_prefs_allow: []
YAML
expect "selective 无 allow 项 -> BLOCK" 1 gate-global-prefs.sh

FIX="$(new_fixture gprefs-legacy-stack)"
stack_ok
expect "legacy stack.yml global_prefs -> PASS" 0 gate-global-prefs.sh

FIX="$(new_fixture gprefs-missing)"
expect "无 prefs 且无 stack -> BLOCK" 1 gate-global-prefs.sh

echo "── gate-spec-coverage ────────────────────────────────────"
FIX="$(new_fixture coverage-pass)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
expect_or_skip_ruby "完整 spec + coverage -> PASS" 0 gate-spec-coverage.sh

FIX="$(new_fixture coverage-no-yml)"
spec_pass_standard
global_prefs_ok
expect_or_skip_ruby "无 spec-coverage.yml -> BLOCK" 1 gate-spec-coverage.sh

FIX="$(new_fixture coverage-no-gprefs)"
spec_pass_standard
spec_coverage_standard
expect_or_skip_ruby "无 global-prefs -> BLOCK" 1 gate-spec-coverage.sh

FIX="$(new_fixture coverage-template-bg)"
cp "$BASH_DIR/../../templates/spec-template.md" "$FIX/spec.md" 2>/dev/null || \
  printf '# Feature\n[Background, goals and success criteria for stakeholders]\n## Input Q&A\n### ②\n- **Q:** x **A:** y\n' > "$FIX/spec.md"
spec_coverage_standard
global_prefs_ok
expect_or_skip_ruby "Background 仍为模板 -> BLOCK" 1 gate-spec-coverage.sh

FIX="$(new_fixture coverage-no-assumption-tag)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
ruby -e "
  f = ENV['F']
  s = File.read(f)
  s = s.sub(/## Assumptions\n- \[ASSUMPTION\][^\n]+\n/, \"## Assumptions\n- Plain assumption without tag\n\")
  File.write(f, s)
" F="$FIX/spec.md" 2>/dev/null || true
expect_or_skip_ruby "Assumptions 无标签(standard) -> BLOCK" 1 gate-spec-coverage.sh

FIX="$(new_fixture coverage-assumption-tag-ok)"
spec_pass_standard
spec_coverage_standard
global_prefs_ok
expect_or_skip_ruby "Assumptions 有 [ASSUMPTION] -> PASS" 0 gate-spec-coverage.sh

FIX="$(new_fixture coverage-no-qa)"
printf '# Feature\n## Background & Goals\nDone.\n' > "$FIX/spec.md"
spec_coverage_standard
global_prefs_ok
expect_or_skip_ruby "Input Q&A 缺失 -> BLOCK" 1 gate-spec-coverage.sh

FIX="$(new_fixture coverage-trivial-pass)"
spec_pass_trivial
spec_coverage_trivial
global_prefs_ok
expect_or_skip_ruby "trivial waived + coverage -> PASS" 0 gate-spec-coverage.sh

echo "── gate-stack ────────────────────────────────────────────"
FIX="$(new_fixture stack-pass)"; stack_ok
expect "confirmed+form+global_prefs (no spec) -> PASS" 0 gate-stack.sh

FIX="$(new_fixture stack-missing)"
expect "无 stack.yml -> BLOCK" 1 gate-stack.sh

FIX="$(new_fixture stack-unconfirmed)"
printf 'form: web\ncomplexity: standard\nglobal_prefs: ignore\nconfirmed: false\n' > "$FIX/stack.yml"
expect "confirmed:false -> BLOCK" 1 gate-stack.sh

FIX="$(new_fixture stack-ui-cli)"
printf 'form: cli\ncomplexity: standard\nui: true\nglobal_prefs: ignore\nconfirmed: true\n' > "$FIX/stack.yml"
expect "ui:true + form:cli -> BLOCK" 1 gate-stack.sh

FIX="$(new_fixture stack-tauri-cli)"
printf 'form: cli\ncomplexity: standard\nglobal_prefs: ignore\nconfirmed: true\nnotes: "Tauri 2 + React"\n' > "$FIX/stack.yml"
expect "Tauri + form:cli -> BLOCK" 1 gate-stack.sh

FIX="$(new_fixture stack-no-prefs)"
printf 'form: web\ncomplexity: standard\nconfirmed: true\n' > "$FIX/stack.yml"
expect "standard 缺 global_prefs -> BLOCK (B3)" 1 gate-stack.sh

FIX="$(new_fixture stack-trivial-no-prefs)"
printf 'form: cli\ncomplexity: trivial\nconfirmed: true\n' > "$FIX/stack.yml"
expect "trivial 免 global_prefs -> PASS (B3)" 0 gate-stack.sh

FIX="$(new_fixture stack-q5-block)"; stack_ok
spec_pass_standard
spec_coverage_standard
expect "stack 已确认但 ⑤ 无 Q&A -> BLOCK" 1 gate-stack.sh

FIX="$(new_fixture stack-q5-pass)"; stack_ok
spec_pass_with_q5
spec_coverage_with_q5
expect "stack 已确认 + ⑤ Q&A -> PASS" 0 gate-stack.sh

echo "── gate-analyze ──────────────────────────────────────────"
FIX="$(new_fixture analyze-pass)"; stack_ok
spec_pass_standard
spec_coverage_standard
printf '# Plan\nImplementation approach.\n' > "$FIX/plan.md"
printf '# Tasks\n- [ ] T001 setup\n' > "$FIX/tasks.md"
expect_or_skip_ruby "clean spec + plan + confirmed stack -> PASS" 0 gate-analyze.sh

FIX="$(new_fixture analyze-no-plan)"; stack_ok
spec_pass_standard
spec_coverage_standard
printf '# Tasks\n- [ ] T001 setup\n' > "$FIX/tasks.md"
expect "无 plan.md -> BLOCK" 1 gate-analyze.sh

FIX="$(new_fixture analyze-missing-story)"; stack_ok
spec_pass_standard
spec_coverage_standard
printf '# Plan\nPlan.\n' > "$FIX/plan.md"
printf '## US1 Login\nUser can log in.\n' >> "$FIX/spec.md"
printf '# Tasks\n- [ ] T001 unrelated setup\n' > "$FIX/tasks.md"
expect "US1 无 task 落点 -> BLOCK" 1 gate-analyze.sh

echo "── gate-verify ───────────────────────────────────────────"
FIX="$(new_fixture verify-no-yml)"; stack_ok
expect "无 verify.yml -> setup ERROR" 2 gate-verify.sh

FIX="$(new_fixture verify-fail-cmd)"
printf 'form: cli\ncomplexity: standard\nglobal_prefs: ignore\nconfirmed: true\n' > "$FIX/stack.yml"
printf '# Spec\nProse only.\n' > "$FIX/spec.md"
printf '# Tasks\n- [ ] T001\n' > "$FIX/tasks.md"
cat > "$FIX/verify.yml" <<'YAML'
form: cli
commands:
  - name: failing
    run: "false"
scan_paths: []
YAML
expect_blocked "命令退出非 0 -> BLOCK" gate-verify.sh

echo "── gate-skill-freshness ──────────────────────────────────"
# Reads the real registry (not a fixture); behaviors below are deterministic.
if "$BASH_DIR/gate-skill-freshness.sh" >/dev/null 2>&1; then
    printf '  \033[32mok\033[0m   %-44s (exit 0)\n' "默认 advisory -> PASS"; pass=$((pass + 1))
else
    printf '  \033[31mFAIL\033[0m %-44s (want 0)\n' "默认 advisory -> PASS"; fail=$((fail + 1))
fi
"$BASH_DIR/gate-skill-freshness.sh" --max-age-days 0 --strict >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    printf '  \033[32mok\033[0m   %-44s (blocked)\n' "--strict + age0 -> BLOCK"; pass=$((pass + 1))
else
    printf '  \033[31mFAIL\033[0m %-44s (expected non-zero)\n' "--strict + age0 -> BLOCK"; fail=$((fail + 1))
fi

echo "── validate-workflow-index ───────────────────────────────"
if [[ "$HAS_RUBY" -eq 1 ]]; then
    if "$BASH_DIR/validate-workflow-index.sh" >/dev/null 2>&1; then
        printf '  \033[32mok\033[0m   %-44s (exit 0)\n' "workflow-index + phase-index"; pass=$((pass + 1))
    else
        printf '  \033[31mFAIL\033[0m %-44s\n' "workflow-index + phase-index"; fail=$((fail + 1))
    fi
else
    printf '  \033[33mskip\033[0m %-44s (no ruby)\n' "workflow-index + phase-index"; skip=$((skip + 1))
fi

echo "── workflow-index charter gate placement ─────────────────"
WI="$SCRIPT_DIR/../workflows/workflow-index.yml"
if [[ -f "$WI" ]]; then
    charter_count=$(grep -c 'gate-charter\.sh' "$WI" 2>/dev/null || echo 0)
    if [[ "$charter_count" -eq 1 ]]; then
        printf '  \033[32mok\033[0m   %-44s\n' "gate-charter.sh appears once"; pass=$((pass + 1))
    else
        printf '  \033[31mFAIL\033[0m %-44s (count=%s)\n' "gate-charter.sh singleton" "$charter_count"; fail=$((fail + 1))
    fi
    if [[ "$HAS_RUBY" -eq 1 ]]; then
        if ruby -ryaml -e '
wi = ARGV[0]
d = YAML.load_file(wi)
gates = (d.dig("phases", "specify", "gates_before_next") || [])
exit(gates.include?("gate-charter.sh") ? 1 : 0)
' "$WI" >/dev/null 2>&1; then
            printf '  \033[32mok\033[0m   %-44s\n' "specify gates omit gate-charter"; pass=$((pass + 1))
        else
            printf '  \033[31mFAIL\033[0m %-44s\n' "specify gates omit gate-charter"; fail=$((fail + 1))
        fi
    else
        printf '  \033[33mskip\033[0m %-44s (no ruby)\n' "specify gates omit gate-charter"; skip=$((skip + 1))
    fi
else
    printf '  \033[31mFAIL\033[0m %-44s\n' "workflow-index.yml missing"; fail=$((fail + 1))
fi

echo "── phase-brief ───────────────────────────────────────────"
if [[ "$HAS_RUBY" -eq 1 ]]; then
FIX=$(new_fixture "phase-brief")
echo "current_phase: specify" > "$FIX/phase.yml"
echo "# spec" > "$FIX/spec.md"
cat > "$FIX/stack.yml" <<'YAML'
form: web
complexity: trivial
ui: false
global_prefs: ignore
confirmed: true
YAML
if SPECIFY_FEATURE_DIRECTORY="$FIX" "$BASH_DIR/phase-brief.sh" --phase specify --questions-only >/dev/null 2>&1; then
    printf '  \033[32mok\033[0m   %-44s (exit 0)\n' "specify --questions-only"; pass=$((pass + 1))
else
    printf '  \033[31mFAIL\033[0m %-44s\n' "specify --questions-only"; fail=$((fail + 1))
fi
if SPECIFY_FEATURE_DIRECTORY="$FIX" "$BASH_DIR/phase-brief.sh" --phase specify --json 2>/dev/null | grep -q '"phase": "specify"'; then
    printf '  \033[32mok\033[0m   %-44s\n' "specify --json has phase"; pass=$((pass + 1))
else
    printf '  \033[31mFAIL\033[0m %-44s\n' "specify --json has phase"; fail=$((fail + 1))
fi
else
    printf '  \033[33mskip\033[0m %-44s (no ruby)\n' "phase-brief tests"; skip=$((skip + 1))
fi

echo "──────────────────────────────────────────────────────────"
echo "gate tests: $pass passed, $fail failed, $skip skipped (ruby)"
[[ "$fail" -eq 0 ]] || exit 1
exit 0
