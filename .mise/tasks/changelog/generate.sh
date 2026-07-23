#!/usr/bin/env bash
#MISE description="Generate CHANGELOG.md from git history"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "Generating CHANGELOG.md..."

if command -v git-cliff &>/dev/null; then
    git-cliff -o "$MISE_PROJECT_ROOT/CHANGELOG.md"
    log_info "✓ CHANGELOG.md updated via git-cliff."
else
    log_warn "git-cliff is not installed. Generating basic CHANGELOG.md from git log."
    cat <<EOF > "$MISE_PROJECT_ROOT/CHANGELOG.md"
# Changelog

All notable changes to this project will be documented in this file.

## Commit History

$(git log --oneline -n 50 | sed 's/^/- /')
EOF
    log_info "✓ CHANGELOG.md generated."
fi
