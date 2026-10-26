#!/usr/bin/env bash
#MISE description="Refresh Terraform lock files for every supported platform"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

# Platforms that run Terraform: CI runners, Linux ARM hosts and macOS laptops.
platforms=(linux_amd64 linux_arm64 darwin_amd64 darwin_arm64)

platform_args=()
for platform in "${platforms[@]}"; do
    platform_args+=("-platform=$platform")
done

find terraform -type f -name '*.tf' -not -path '*/.terraform/*' -not -path 'terraform/templates/*' -exec dirname {} \; |
    sort -u |
    while IFS= read -r dir; do
        log_info "Locking providers in $dir"
        terraform -chdir="$dir" providers lock "${platform_args[@]}"
    done

log_info "✓ All Terraform lock files cover: ${platforms[*]}"
