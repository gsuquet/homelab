#!/usr/bin/env bash
#MISE description="Validate rendered Kubernetes manifests with kubeconform"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

find kubernetes -type f -path "*/manifests/*.yaml" -print0 |
    xargs -0 kubeconform -summary -ignore-missing-schemas

log_info "✓ All rendered manifests are valid."
