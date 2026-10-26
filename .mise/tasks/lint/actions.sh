#!/usr/bin/env bash
#MISE description="Lint GitHub Actions workflows with actionlint and zizmor"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

log_info "Running actionlint..."
actionlint

log_info "Running zizmor..."
zizmor --offline --no-progress .github/workflows

log_info "✓ GitHub Actions workflows pass actionlint and zizmor."
