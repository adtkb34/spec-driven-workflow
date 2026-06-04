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

echo "── gate-clarify ──────────────────────────────────────────"
FIX="$(new_fixture clarify-pass)"
printf '# Spec\nAll requirements resolved.\n' > "$FIX/spec.md"
expect "clean spec -> PASS" 0 gate-clarify.sh

FIX="$(new_fixture clarify-block)"
printf '# Spec\nThe limit is [NEEDS CLARIFICATION: how many?].\n' > "$FIX/spec.md"
expect "残留 NEEDS CLARIFICATION -> BLOCK" 1 gate-clarify.sh

FIX="$(new_fixture clarify-todo)"
printf '# Spec\nTODO: decide auth.\n' > "$FIX/spec.md"
expect "残留 TODO -> BLOCK" 1 gate-clarify.sh

echo "── gate-stack ────────────────────────────────────────────"
FIX="$(new_fixture stack-pass)"; stack_ok
expect "confirmed+form+global_prefs -> PASS" 0 gate-stack.sh

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

echo "── gate-analyze ──────────────────────────────────────────"
FIX="$(new_fixture analyze-pass)"; stack_ok
printf '# Spec\nNo user-story IDs here; just prose.\n' > "$FIX/spec.md"
printf '# Tasks\n- [ ] T001 setup\n' > "$FIX/tasks.md"
expect "clean spec + confirmed stack -> PASS" 0 gate-analyze.sh

FIX="$(new_fixture analyze-missing-story)"; stack_ok
printf '# Spec\n## US1 Login\nUser can log in.\n' > "$FIX/spec.md"
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
if "$BASH_DIR/validate-workflow-index.sh" >/dev/null 2>&1; then
    printf '  \033[32mok\033[0m   %-44s (exit 0)\n' "workflow-index + phase-index"; pass=$((pass + 1))
else
    printf '  \033[31mFAIL\033[0m %-44s\n' "workflow-index + phase-index"; fail=$((fail + 1))
fi

echo "── phase-brief ───────────────────────────────────────────"
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

echo "──────────────────────────────────────────────────────────"
echo "gate tests: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
exit 0
