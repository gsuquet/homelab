#!/usr/bin/env bash
#MISE description="Lint shell scripts with ShellCheck and check formatting with shfmt"

set -euo pipefail

# shellcheck source=../_base/log.sh
source "$MISE_PROJECT_ROOT/.mise/tasks/_base/log.sh"

cd "$MISE_PROJECT_ROOT"

files=()
while IFS= read -r file; do
    files+=("$file")
done < <(git ls-files -- '*.sh')

log_info "Running ShellCheck on ${#files[@]} script(s)..."
shellcheck "${files[@]}"

# shfmt reads its style from .editorconfig.
log_info "Checking formatting with shfmt..."
if ! shfmt -d "${files[@]}"; then
    log_error "Shell scripts are not formatted. Run 'shfmt -w' on the files above."
    exit 1
fi

log_info "✓ Shell scripts pass ShellCheck and shfmt."
