#!/usr/bin/env bash
#MISE description="Generate reference documentation for Terraform modules and Ansible roles"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "Generating Terraform module documentation..."
"$MISE_PROJECT_ROOT/.mise/tasks/tf/docs.sh"

# Ensure target ref directory for terraform modules exists and copy module READMEs to reference docs
TF_REF_DIR="$MISE_PROJECT_ROOT/docs/reference/terraform-modules"
for module_dir in "$MISE_PROJECT_ROOT/terraform/modules"/*; do
    if [ -d "$module_dir" ]; then
        mod_name="$(basename "$module_dir")"
        mkdir -p "$TF_REF_DIR/$mod_name"
        if [ -f "$module_dir/README.md" ]; then
            cp "$module_dir/README.md" "$TF_REF_DIR/$mod_name/index.md"
        fi
    fi
done

log_info "Generating Ansible role documentation..."
"$MISE_PROJECT_ROOT/scripts/generate-ansible-docs.sh"

log_info "All documentation generation complete."
