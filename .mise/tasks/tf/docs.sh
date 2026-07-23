#!/usr/bin/env bash
#MISE description="Generate reference documentation for all Terraform modules using terraform-docs"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

if ! command -v terraform-docs &>/dev/null; then
    log_error "terraform-docs is not installed. Install it with: brew install terraform-docs"
    exit 1
fi

MODULES_DIR="$MISE_PROJECT_ROOT/terraform/modules"

if [ ! -d "$MODULES_DIR" ]; then
    log_warn "No modules directory found at $MODULES_DIR"
    exit 0
fi

rendered_count=0
error_count=0

# Process each module directory (one level deep)
while IFS= read -r module_dir; do
    module_name="$(basename "$module_dir")"
    readme="$module_dir/README.md"

    log_info "Generating docs for module: $module_name"

    if terraform-docs markdown table \
        --output-file "$readme" \
        --output-mode inject \
        "$module_dir" 2>/dev/null; then
        log_info "✓ $module_name → $readme"
        ((rendered_count += 1))
    else
        log_error "✗ Failed to generate docs for $module_name"
        ((error_count += 1))
    fi
done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

echo ""
log_info "===================================="
log_info "Documentation generation complete!"
log_info "Modules processed: $rendered_count"
[ $error_count -gt 0 ] && log_error "Errors: $error_count"
log_info "===================================="

exit $error_count
