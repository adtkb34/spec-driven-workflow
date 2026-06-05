#!/usr/bin/env bash
# Deprecated: flat specs/NNN-* layout removed. Use layered create-worktree.sh instead.
set -euo pipefail
echo "create-new-feature.sh is deprecated (flat specs/NNN-* no longer supported)." >&2
echo "" >&2
echo "Create a module and charter:" >&2
echo "  .specify/scripts/bash/create-worktree.sh module <module-slug> --title \"My Module\"" >&2
echo "  .specify/scripts/bash/create-worktree.sh charter --module <module-slug> <charter-slug>" >&2
echo "" >&2
echo "Import an old flat directory once:" >&2
echo "  .specify/scripts/bash/migrate-specs-layout.sh --source specs/001-old-name" >&2
echo "" >&2
echo "See .specify/memory/layered-artifacts.md" >&2
exit 1
