#!/usr/bin/env bash
# Sync verify-coverage.yml + verify.yml + verify.md scaffold from spec.md + tasks.md.
#
# Usage:
#   sync-verify.sh           # write/merge (default)
#   sync-verify.sh --check   # exit 1 if verify.yml/verify.md not aligned with coverage
#   sync-verify.sh --dry-run # print coverage YAML only
#
# Called automatically by gate-verify.sh before running commands.

set -uo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

MODE="sync"
for arg in "$@"; do
    case "$arg" in
        --check) MODE="check" ;;
        --dry-run) MODE="dry-run" ;;
    esac
done

_paths_output=$(get_feature_paths) || { echo "SYNC-VERIFY: ERROR resolving feature paths" >&2; exit 2; }
eval "$_paths_output"
unset _paths_output

RUBY_SCRIPT="$SCRIPT_DIR/../ruby/sync_verify.rb"
if [[ ! -f "$RUBY_SCRIPT" ]]; then
    echo "SYNC-VERIFY: ERROR missing $RUBY_SCRIPT" >&2
    exit 2
fi
command -v ruby >/dev/null 2>&1 || { echo "SYNC-VERIFY: ERROR requires ruby" >&2; exit 2; }

export SYNC_VERIFY_MODE="$MODE"
ruby "$RUBY_SCRIPT" "$FEATURE_DIR" "$REPO_ROOT"
exit $?
