#!/usr/bin/env bash
#MISE description="Generate reference documentation for Terraform modules"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

log_info "Generating Terraform module documentation..."
"$MISE_PROJECT_ROOT/.mise/tasks/tf/docs.sh"

# Ensure target ref directory for terraform modules exists and copy module READMEs to reference docs
TF_REF_DIR="$MISE_PROJECT_ROOT/docs/reference/terraform-modules"
for module_dir in "$MISE_PROJECT_ROOT/modules"/*; do
    if [ -d "$module_dir" ] && [ "$(basename "$module_dir")" != "_template" ]; then
        mod_name="$(basename "$module_dir")"
        mkdir -p "$TF_REF_DIR/$mod_name"
        if [ -f "$module_dir/README.md" ]; then
            # The copy sits four levels below the repo root, so a link that is relative to
            # the module folder must point back to modules/<module>/. Absolute URLs, anchors
            # and absolute paths stay unchanged (they do not match the pattern).
            sed -E "s#\]\(([A-Za-z0-9_.-]+[/)#])#](../../../../modules/$mod_name/\1#g" \
                "$module_dir/README.md" > "$TF_REF_DIR/$mod_name/index.md"
        fi
    fi
done

log_info "All documentation generation complete."
