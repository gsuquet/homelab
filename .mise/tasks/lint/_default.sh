#!/usr/bin/env bash
#MISE description="Run every linter and check. CI and pre-commit run the same tasks."
#MISE depends=["lint:terraform", "lint:policy", "lint:actions", "lint:shell", "lint:docs", "schemas:test", "schemas:check"]

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "✓ All linters and checks passed."
