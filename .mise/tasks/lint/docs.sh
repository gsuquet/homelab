#!/usr/bin/env bash
#MISE description="Check the Markdown files against the ASD-STE100 rules with Vale"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

files=()
while IFS= read -r file; do
    files+=("$file")
done < <(git ls-files -- '*.md')

# Only errors fail the check. Run `vale <file>` to also see the warnings.
log_info "Running Vale on ${#files[@]} Markdown file(s)..."
vale --no-wrap --minAlertLevel=error "${files[@]}"

log_info "✓ The documentation passes the Vale error rules."
