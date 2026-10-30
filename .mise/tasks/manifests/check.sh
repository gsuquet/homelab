#!/usr/bin/env bash
#MISE description="Check if manifests are up-to-date"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

manifests=(':(glob)kubernetes/**/manifests/**' ':(glob)gitops/**/rendered/**')

mise run manifests:render

if ! git diff --quiet -- "${manifests[@]}" || [ -n "$(git ls-files --others --exclude-standard -- "${manifests[@]}")" ]; then
    log_error "Manifests are out of date. Run 'mise run manifests:render' and commit the changes."
    git status --short -- "${manifests[@]}"
    git diff -- "${manifests[@]}"
    exit 1
fi

log_info "✓ All manifests are up to date."
