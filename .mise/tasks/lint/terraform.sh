#!/usr/bin/env bash
#MISE description="Check Terraform formatting and lint all Terraform code with TFLint"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

log_info "Checking Terraform formatting..."
if ! terraform fmt -check -recursive -diff; then
    log_error "Terraform files are not formatted. Run 'terraform fmt -recursive'."
    exit 1
fi

# terraform/templates/ holds empty stubs that are not valid modules yet.
dirs=()
mapfile -t dirs < <(git ls-files -- '*.tf' ':!:terraform/templates/**' | xargs -n1 dirname | sort -u)

failed=0
for dir in "${dirs[@]}"; do
    log_info "Running TFLint in $dir..."
    tflint --chdir="$dir" --config="$MISE_PROJECT_ROOT/.tflint.hcl" --format compact || failed=1
done

if [ "$failed" -ne 0 ]; then
    log_error "TFLint found issues."
    exit 1
fi

log_info "✓ Terraform code is formatted and passes TFLint."
