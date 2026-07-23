#!/usr/bin/env bash
#MISE description="Check if generated documentation is up to date"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "Running documentation generation check..."
"$MISE_PROJECT_ROOT/.mise/tasks/doc/generate.sh"

if ! git diff --quiet docs/reference/terraform-modules docs/reference/ansible-roles terraform/modules; then
    log_error "Documentation is out of date! Run 'mise run doc:generate' and commit the changes."
    git diff --stat docs/reference/terraform-modules docs/reference/ansible-roles terraform/modules
    exit 1
else
    log_info "✓ Documentation is up to date."
fi
